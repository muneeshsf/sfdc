import json
import subprocess
import csv

# Salesforce org alias
org_alias = 'metaprod'

# Query PartnerFundClaim records with Approved status
query_partner_fund_claim = "SELECT Id FROM PartnerFundClaim WHERE Status = 'Approved'and BudgetId ='0Cw8V000000wu6MSAQ'"
command_partner_fund_claim = f"sfdx force:data:soql:query --query \"{query_partner_fund_claim}\" --target-org {org_alias} --json"
result_partner_fund_claim = subprocess.run(command_partner_fund_claim, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

record_count = 0

if result_partner_fund_claim.returncode != 0:
    print(f"Error executing command: {command_partner_fund_claim}")
    print(f"Return code: {result_partner_fund_claim.returncode}")
    print(f"Error message: {result_partner_fund_claim.stderr.decode('utf-8')}")
else:
    try:
        result_partner_fund_claim_json = json.loads(result_partner_fund_claim.stdout.decode('utf-8'))
        partner_fund_claim_records = result_partner_fund_claim_json['result']['records']

        with open('ExtractCommands.csv', 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['ContentVersionId', 'Title']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

            writer.writeheader()
            for partner_fund_claim_record in partner_fund_claim_records:
                if record_count >= 1000:
                    break
                partner_fund_claim_id = partner_fund_claim_record['Id']

                # Query ContentDocumentLink
                query = f"SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = '{partner_fund_claim_id}' AND ContentDocument.FileType = 'PDF'"
                command = f"sfdx force:data:soql:query --query \"{query}\" --target-org {org_alias} --json"
                result = subprocess.run(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                if result.returncode != 0:
                    print(f"Error executing command: {command}")
                    print(f"Return code: {result.returncode}")
                    print(f"Error message: {result.stderr.decode('utf-8')}")
                else:
                    try:
                        result_json = json.loads(result.stdout.decode('utf-8'))
                        records = result_json['result']['records']

                        for record in records:
                            content_document_id = record['ContentDocumentId']

                            # Query ContentDocument
                            query_document = f"SELECT Id, Title FROM ContentDocument WHERE Id = '{content_document_id}'"
                            command_document = f"sfdx force:data:soql:query --query \"{query_document}\" --target-org {org_alias} --json"
                            result_document = subprocess.run(command_document, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                            if result_document.returncode != 0:
                                print(f"Error executing command: {command_document}")
                                print(f"Return code: {result_document.returncode}")
                                print(f"Error message: {result_document.stderr.decode('utf-8')}")
                            else:
                                try:
                                    result_document_json = json.loads(result_document.stdout.decode('utf-8'))
                                    document_records = result_document_json['result']['records']

                                    if document_records and 'Id' in document_records[0]:
                                        content_document_title = document_records[0]['Title']
                                        content_document_id = document_records[0]['Id']

                                        # Query ContentVersion
                                        query_version = f"SELECT Id FROM ContentVersion WHERE ContentDocumentId = '{content_document_id}' AND IsLatest = true"
                                        command_version = f"sfdx force:data:soql:query --query \"{query_version}\" --target-org {org_alias} --json"
                                        result_version = subprocess.run(command_version, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

                                        if result_version.returncode != 0:
                                            print(f"Error executing command: {command_version}")
                                            print(f"Return code: {result_version.returncode}")
                                            print(f"Error message: {result_version.stderr.decode('utf-8')}")
                                        else:
                                            try:
                                                result_version_json = json.loads(result_version.stdout.decode('utf-8'))
                                                version_records = result_version_json['result']['records']

                                                if version_records and 'Id' in version_records[0]:
                                                    content_version_id = version_records[0]['Id']
                                                    writer.writerow({'ContentVersionId': content_version_id, 'Title': content_document_title})
                                                    record_count += 1
                                            except json.JSONDecodeError:
                                                print(f"Error parsing JSON: {result_version.stdout.decode('utf-8')}")
                                except json.JSONDecodeError:
                                    print(f"Error parsing JSON: {result_document.stdout.decode('utf-8')}")
                    except json.JSONDecodeError:
                        print(f"Error parsing JSON: {result.stdout.decode('utf-8')}")
    except json.JSONDecodeError:
        print(f"Error parsing JSON: {result_partner_fund_claim.stdout.decode('utf-8')}")
