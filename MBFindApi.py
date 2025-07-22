import os
import csv
import re

def extract_info(xml_file):
    try:
        with open(xml_file, 'r') as file:
            xfile=xml_file
            content = file.read()
            api_version_match = re.search(r'<apiVersion>(.*?)</apiVersion>', content)
            status_match = re.search(r'<status>(.*?)</status>', content)
            api_version = api_version_match.group(1) if api_version_match else None
            status = status_match.group(1) if status_match else None
            return api_version, status
    except Exception as e:
        print(f"Error parsing {xml_file}: {str(e)}")
    return None, None

def main():
    with open('MBoutput.csv', 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['File Name', 'Component Name', 'Component Type', 'API Version', 'Status'])
        for root, dirs, files in os.walk('.'):
            for file in files:
                if file.endswith('.xml'):
                    xml_file = os.path.join(root, file)
                    api_version, status = extract_info(xml_file)
                    if api_version is not None or status is not None:
                        component_name = file.split('.')[0].replace('-meta', '')
                        component_type = root.split('\\')[4]
                        writer.writerow([file, component_name, component_type, api_version, status])

                        print(f"component_type : {component_type} :")
if __name__ == '__main__':
    main()
