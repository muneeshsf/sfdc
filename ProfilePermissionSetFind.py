import subprocess
import csv
import os
from datetime import datetime, date

# === CONFIGURATION ===
profile_name = "BMG Partner"  # Change to your target profile
permset_name = "BMG- Salesforce CPQ Partner User"  # Change to your permission set API name
username_alias = "metaprod"  # Your SFDX org alias
dry_run = True  # True = simulate, False = assign
output_csv = r"c:\Muneesh\users_without_permset.csv"
sf_path = r"C:\Program Files\sf\bin\sf.cmd"  # Update this path

def calculate_days_since_last_login(last_login_date):
    if not last_login_date:
        return ""
    last_login_date = datetime.strptime(last_login_date.split(".")[0], "%Y-%m-%dT%H:%M:%S")
    today = datetime.now()
    return (today - last_login_date).days

def run_sfdx(query, query_type):
    if not os.path.exists(sf_path):
        print("Salesforce CLI not found at the specified path.")
        return None
    
    if query_type == "users":
        full_command = f'"{sf_path}" data query --query "{query}" --target-org {username_alias} --result-format csv'
    elif query_type == "permset":
        full_command = f'"{sf_path}" data query --query "{query}" --target-org {username_alias} --result-format csv'
    else:
        print("Invalid query type.")
        return None
    
    try:
        result = subprocess.run(full_command, capture_output=True, shell=True, check=True)
        output = result.stdout.decode('utf-8', errors='ignore')
        return output
    except subprocess.CalledProcessError as e:
        error_output = e.stderr.decode('utf-8', errors='ignore')
        print(f"\nError running: {full_command}\n{error_output}")
        return None


def get_user_ids_by_profile():
    print(f"\n Fetching active users with profile: {profile_name}")
    query = f"SELECT Id, Name, Username, Email, IsActive, Profile.Name, LastLoginDate FROM User WHERE Profile.Name = '{profile_name}' AND IsActive = true"
    output = run_sfdx(query, "users")
    users = []
    if output:
        reader = csv.DictReader(output.strip().splitlines())
        for row in reader:
            users.append({
                "Id": row["Id"],
                "Name": row["Name"],
                "Username": row["Username"],
                "Email": row["Email"],
                "Active": row["IsActive"],
                "Profile Name": row["Profile.Name"],
                "Last Login Date": row["LastLoginDate"],
                "Days Since Last Login": calculate_days_since_last_login(row["LastLoginDate"]),
                "Permission Set": permset_name
            })
    return users

def get_user_ids_with_permset():
    print(f"\n Fetching users already assigned to permission set: {permset_name}")
    query = f"SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name = '{permset_name}'"
    output = run_sfdx(query, "permset")
    assigned_ids = set()
    if output:
        reader = csv.DictReader(output.strip().splitlines())
        for row in reader:
            assigned_ids.add(row["AssigneeId"])
    return assigned_ids

def assign_permset_to_users(users):
    print(f"\n Assigning permission set '{permset_name}' to {len(users)} users...")
    for user in users:
        user_id = user["Id"]
        print(f" - Processing user {user['Username']} ({user_id})")
        if dry_run:
            print(f"   [Dry Run] Would assign {permset_name} to {user_id}")
        else:
            full_command = f'"{sf_path}" org assign permset --name "{permset_name}" --on-behalf-of {user_id} --target-org {username_alias}'
            try:
                result = subprocess.run(full_command, capture_output=True, text=True, encoding='utf-8', errors='ignore', shell=True, check=True)
                print(f"   Success: {user_id}")
            except subprocess.CalledProcessError as e:
                print(f"   Failed: {user_id}\n{e.stderr}")

def export_users_to_csv(users, filename):
    if not users:
        print("\nAll users already have the permission set.")
        return
    fieldnames = ["Id", "Name", "Username", "Email", "Active", "Profile Name", "Permission Set", "Last Login Date", "Days Since Last Login"]
    with open(filename, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(users)
    print(f"\nExported {len(users)} users to: {filename}")

def main():
    all_users = get_user_ids_by_profile()
    assigned_ids = get_user_ids_with_permset()
    users_to_assign = [u for u in all_users if u["Id"] not in assigned_ids]
    for user in users_to_assign:
        user["Permission Set"] = "Not Assigned"
    export_users_to_csv(users_to_assign, output_csv)
    assign_permset_to_users(users_to_assign)

if __name__ == "__main__":
    main()