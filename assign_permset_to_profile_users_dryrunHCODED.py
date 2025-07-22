import subprocess
import csv

# === CONFIGURATION ===
profile_name = "BMG Partner"  # Change to your target profile
permset_name = "BMG- Salesforce CPQ Partner User"  # Change to your permission set API name
username_alias = "metaprod"  # Your SFDX org alias
dry_run = True  # True = simulate, False = assign
output_csv = "users_without_permset.csv"

def run_sfdx(command):
    full_command = ["sfdx"] + command
    if username_alias:
        full_command += ["-u", username_alias]
    result = subprocess.run(full_command, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"\nError running: {' '.join(full_command)}\n{result.stderr}")
        return None
    return result.stdout

def get_user_ids_by_profile():
    print(f"\n🔍 Fetching active users with profile: {profile_name}")
    query = f"SELECT Id, Name, Username, Email FROM User WHERE Profile.Name = '{profile_name}' AND IsActive = true"
    output = run_sfdx(["force:data:soql:query", "-q", query, "-r", "csv"])
    users = []
    if output:
        reader = csv.DictReader(output.strip().splitlines())
        for row in reader:
            users.append(row)
    return users

def get_user_ids_with_permset():
    print(f"\n🔍 Fetching users already assigned to permission set: {permset_name}")
    query = f"SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name = '{permset_name}'"
    output = run_sfdx(["force:data:soql:query", "-q", query, "-r", "csv"])
    assigned_ids = set()
    if output:
        reader = csv.DictReader(output.strip().splitlines())
        for row in reader:
            assigned_ids.add(row["AssigneeId"])
    return assigned_ids

def assign_permset_to_users(users):
    print(f"\n🚀 Assigning permission set '{permset_name}' to {len(users)} users...")
    for user in users:
        user_id = user["Id"]
        print(f" - Processing user {user['Username']} ({user_id})")
        if dry_run:
            print(f"   [Dry Run] Would assign {permset_name} to {user_id}")
        else:
            #result = run_sfdx(["force:user:permset:assign", "-n", permset_name, "-o", user_id])
            if result:
                print(f"   ✅ Success: {user_id}")
            else:
                print(f"   ❌ Failed: {user_id}")

def export_users_to_csv(users, filename):
    if not users:
        print("\n✅ All users already have the permission set.")
        return
    with open(filename, "w", newline="") as csvfile:
        fieldnames = users[0].keys()
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(users)
    print(f"\n📁 Exported {len(users)} users to: {filename}")

def main():
    all_users = get_user_ids_by_profile()
    assigned_ids = get_user_ids_with_permset()
    users_to_assign = [u for u in all_users if u["Id"] not in assigned_ids]
    export_users_to_csv(users_to_assign, output_csv)
    assign_permset_to_users(users_to_assign)

if __name__ == "__main__":
    main()