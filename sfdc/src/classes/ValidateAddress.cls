public class ValidateAddress {
    public static Boolean AsyncValidationFlag = false;
    
    @Future(callout=true) 
    public static void validateAddressSOAP(Set<ID> ids) {
        try {
            // Build list of addresses to validate
            Map<ID, Candidate__c> mapCands = findCandidates(ids);
            List<ValidateAddressSOAP.addressSOAP> listAddress = new List<ValidateAddressSOAP.addressSOAP>();
            for (Candidate__c cand : mapCands.values()) {
                ValidateAddressSOAP.addressSOAP address = new ValidateAddressSOAP.addressSOAP();
                address.id = cand.id;
                address.line1 = cand.Street_Address_1__c;
                address.line2 = cand.Street_Address_2__c;
                address.city = cand.city__c;
                address.state = cand.state_Province__c;
                address.country = cand.country__c;
                address.zipCode = cand.zip_postal_code__c;
                listAddress.add(address);
            }
                        
            // Declare a new variable called "port" of type ValidateAddressesSOAP.ValidateAddressesPort using the default constructor
            ValidateAddressSOAP.ValidateAddressesPort port = new ValidateAddressSOAP.ValidateAddressesPort();
            
			// Declare a variable called "listResult" of type ValidateAddressSOAP.validationResultSOAP
			List<ValidateAddressSOAP.ValidationResultSOAP> listResult;

			// Initialize this variable the result of calling the method ValidateAddresses method of the "port" variable, passing the listAddress variable.
			listResult = port.ValidateAddresses(listAddress);

            // Verify results
            for (ValidateAddressSOAP.validationResultSOAP result : listResult) {
                Candidate__c cand = mapCands.get(result.testAddress.id);
                if (result.isValid) {
                    cand.Valid_Address__c = true;
                    cand.Address_Error__c = null;
                } else {
                    cand.Valid_Address__c = false;
                    cand.Address_Error__c = 'Invalid Address';
                }
            }
            
            // Update Candidate
            AsyncValidationFlag = true;
            update mapCands.values();
        } catch (Exception ex) {
            // Handle Exception
            System.debug('ERROR: '+ ex);
            Error_Log__c log = new Error_Log__c();
            log.trace__c = ex.getCause() + '\n' + ex.getMessage();
            insert log;        
        }
    }
       
    private static Map<ID, Candidate__c> findCandidates(Set<ID> ids) {
        Map<ID, Candidate__c> output;
        output = new Map<ID, Candidate__c>([SELECT ID, Street_Address_1__c, Street_Address_2__c, city__c,
                                                state_Province__c, country__c, zip_postal_code__c
                                            FROM candidate__c
                                            WHERE id in :ids]);
        return output;
    }
}