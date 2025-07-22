public class ADS_AccountCreditRequestManagement {

  // to skip execution of all code on Account trigger, except delete triggers
  public static Boolean shallSkipAllTriggerCode = false;
  public static Boolean shouldRun = true;
  public static Boolean hasApprovalReqSubmittedInThisTxn = false;

  public static final String STATUS_SENT = 'Sent';
  private static final Set<String> OPEN_CREDIT_REQUEST_STATUSES =
    new Set<String> {'Draft', 'Submitted', 'Rejected', 'Sent'};

  private static final String STATUS_APPROVED = 'Approved';
  private static final String STATUS_EXPIRED = 'Expired';
  private static final String STATUS_NEW_REJECTED = 'New - Rejected';
  private static final String STATUS_REJECTED = 'Rejected';
  private static final String STATUS_SUBMITTED = 'Submitted';
  private static final String UNITY_BOT_ID = ADS_GenericConstants.UNITY_BOT_ID;
  private static final String VERIFIED = 'Verified';

  private static final Map<String, Schema.RecordTypeInfo> rtACRMapByName =
    Account_Credit_Request__c.SObjectType.getDescribe().
    getRecordTypeInfosByName();

  private static Id approvedRTId = rtACRMapByName
    .get('Auto Request Approved').getRecordTypeId();

  private static Id newRTId = rtACRMapByName
    .get('New').getRecordTypeId();

  private static Id newClosedRTId = rtACRMapByName
    .get('New - Closed').getRecordTypeId();

  private static Id increaseOpenRTId = rtACRMapByName
    .get('Increase - Open').getRecordTypeId();

  public static void beforeInsert(List<Account_Credit_Request__c> newList) {
    if (shallSkipAllTriggerCode) {
      return;
    }
    defaultCurrencyFromAccount(newList, null);
    setEncryptionId(newList);
    setAccountOmegaManual(newList);
  }

  public static void beforeUpdate(List<Account_Credit_Request__c> newList,
    Map<Id, Account_Credit_Request__c> oldMap) {

    if (shallSkipAllTriggerCode || !shouldRun) {
      return;
    }
    defaultCurrencyFromAccount(newList, oldMap);
  }

  public static void afterInsert(List<Account_Credit_Request__c> newList) {
    if (shallSkipAllTriggerCode) {
      return;
    }
    updateAccountsForOpenAndApprovedRequests(newList, null);
    autoSubmitForApproval(newList, null);
    if (!System.isBatch() && !System.isFuture()) {
      getDunsForGDMReport(newList);
    }
  }

  public static void afterUpdate(List<Account_Credit_Request__c> newList,
    Map<Id, Account_Credit_Request__c> oldMap) {

    if (shallSkipAllTriggerCode || !shouldRun) {
      return;
    }
    updateAccountsForOpenAndApprovedRequests(newList, oldMap);
    autoSubmitForApproval(newList, oldMap);
  }

  public static void afterDelete(List<Account_Credit_Request__c> oldList) {
    updateAccountsForOpenAndApprovedRequests(oldList, null);
  }

  public static void afterUndelete(List<Account_Credit_Request__c> newList) {
    updateAccountsForOpenAndApprovedRequests(newList, null);
  }

  private static void defaultCurrencyFromAccount(
    List<Account_Credit_Request__c> newList,
    Map<Id, Account_Credit_Request__c> oldMap) {

    Set<Id> acctIds = new Set<Id>();
    for (Account_Credit_Request__c acr : newList) {
      Account_Credit_Request__c oldAcr = null;
      if (oldMap != null) {
        oldAcr = oldMap.get(acr.Id);
      }

      if (acr.Account__c != null) {
        acctIds.add(acr.Account__c);
      }
    }

    if (acctIds.isEmpty()) {
      return;
    }

    Set<String> billingCountries = new Set<String>();
    Map<String, Country_Reference__c> isoCodeToCountryMap =
      new Map<String, Country_Reference__c>();

    Map<Id, Account> acctMap = new Map<Id, Account>([select Id,
                                                            CurrencyIsoCode,
                                                            BillingCountry
                                                     from Account
                                                     where Id in :acctIds]);

    for (Account a : acctMap.values()) {
      billingCountries.add(a.BillingCountry);
    }

    for (Country_Reference__c c : [select Id, ISO_Country_Code__c,
                                          Country_Minimum_Request__c,
                                          CurrencyIsoCode
                                   from Country_Reference__c
                                   where ISO_Country_Code__c in
                                           :billingCountries]) {

      isoCodeToCountryMap.put(c.ISO_Country_Code__c, c);
    }

    for (Account_Credit_Request__c acr : newList) {
      if (acctMap.containsKey(acr.Account__c) && (oldMap == null ||
        oldMap.get(acr.Id).Account__c != acr.Account__c)) {

        acr.CurrencyIsoCode = acctMap.get(acr.Account__c).CurrencyIsoCode;
        Country_Reference__c cr = isoCodeToCountryMap.get(acctMap.get
          (acr.Account__c).BillingCountry);

        if (cr != null) {
          if (cr.CurrencyIsoCode == acr.CurrencyIsoCode) {
            acr.Country_Minimum__c = cr.Country_Minimum_Request__c;
          } else {
            acr.Country_Minimum__c = CurrencyManagement.getConvertedAmount(
              cr.Country_Minimum_Request__c, cr.CurrencyIsoCode,
              acr.CurrencyIsoCode, Date.today())
              .setScale(0, System.RoundingMode.HALF_UP);
          }
          if (acr.RecordTypeId == newRTId &&
            acr.BM_Creator__c != 'Ads Payments Invoicing') {

            acr.Proposed_Online_Credit_Limit__c = acr.Country_Minimum__c;
          }
        }

        if (acr.RecordTypeId == newRTId &&
          UserInfo.getUserId() != UNITY_BOT_ID &&
          acr.WP_Application__c == false) {

          acr.Credit_App_Status__c = STATUS_SENT;
        }
      }
    }
  }

  private static void setEncryptionId(List<Account_Credit_Request__c> newList) {
    String randomIntegerStr = String.valueOf(Datetime.now().getTime()) +
      String.valueOf(Crypto.getRandomInteger());

    for (Account_Credit_Request__c acr : newList) {
      acr.Encryption_Id__c = ADS_StringUtils.getRandomMD5HashEncryptedString(
        randomIntegerStr);
    }
  }

  private static void setAccountOmegaManual(
    List<Account_Credit_Request__c> newList) {

    Set<Id> acctIds = new Set<Id>();
    for (Account_Credit_Request__c acr : newList) {
      if (acr.Account__c != null) {
        acctIds.add(acr.Account__c);
      }
    }

    if (acctIds.isEmpty()) {
      return;
    }

    Map<Id, String> aIdToOmegaManualMap = new Map<Id, String>();
    for (Account a : [select Id, Omega_Account_Number__c,
                             Credit_Ultimate_Parent__c
                      from Account
                      where Credit_Ultimate_Parent__c in :acctIds
                      and Omega_Account_Number__c != null]) {

      Id cpId = a.Credit_Ultimate_Parent__c;
      String omegaManual = aIdToOmegaManualMap.containsKey(cpId) ?
        aIdToOmegaManualMap.get(cpId) :
        '';
      omegaManual += a.Omega_Account_Number__c + ',';
      aIdToOmegaManualMap.put(cpId, omegaManual);
    }

    for (Account_Credit_Request__c acr : newList) {
      if (aIdToOmegaManualMap.containsKey(acr.Account__c)) {
        acr.Account_Omega_Manual__c =
          aIdToOmegaManualMap.get(acr.Account__c).removeEnd(',');
      }
    }
  }

  private static void updateAccountsForOpenAndApprovedRequests(
    List<Account_Credit_Request__c> acrList,
    Map<Id, Account_Credit_Request__c> oldMap) {

    Set<Id> accountIds = new Set<Id>();
    Set<Id> allAccountIds = new Set<Id>();
    List<Account> childAccounts = new List<Account>();
    List<Contact> contactsToInsert = new List<Contact>();
    Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>();
    Map<Id, Site__c> addressToUpdate = new Map<Id, Site__c>();

    // Account changed, update new account to true
    for (Account_Credit_Request__c acr : acrList) {
      Account_Credit_Request__c oldAcr = null;
      if (oldMap != null) {
        oldAcr = oldMap.get(acr.Id);
      }

      if (acr.Account__c != null &&
        OPEN_CREDIT_REQUEST_STATUSES.contains(acr.Credit_App_Status__c) &&
        (oldAcr == null || (oldAcr != null &&
          !OPEN_CREDIT_REQUEST_STATUSES.contains(oldAcr.Credit_App_Status__c)))
        ) {

        accountIds.add(acr.Account__c);
      }

      if (oldAcr != null && acr.Account__c != null
        && oldAcr.Account__c != acr.Account__c
        && OPEN_CREDIT_REQUEST_STATUSES.contains(acr.Credit_App_Status__c)) {

          accountIds.add(acr.Account__c);
      }

      allAccountIds.add(acr.Account__c);
    }

    // Part1: Open Request update to Accounts
    if (!accountIds.isEmpty()) {
      for (AggregateResult ar :
        [select Account__c
         from Account_Credit_Request__c
         where Account__c in :accountIds
         and Credit_App_Status__c in :OPEN_CREDIT_REQUEST_STATUSES
         group by Account__c
         having count(Id) > 0]) {

        Id aId = (Id)ar.get('Account__c');

        accountsToUpdateMap.put(aId, new Account(Id = aId,
          Account_Credit_Request_Open__c = true));
      }
    }

    Map<Id, Account> accountMap = new Map<Id, Account>(
      [select Id, Online_Credit_Limit__c, Last_Credit_Evaluation__c,
              Last_Evaluated_By__c, Automatic_Credit_Increase_Count__c,
              Account_Credit_Request_Open__c, IO_Credit_Limit__c,
              Verification_Status__c,
              (select Id, Address_Line_1__c, Address_Line_2__c,
                      Address_Line_3__c, Address_Line_4__c, City__c,
                      State__c, Postal_Code__c, Country__c
               from Sites__r
               where HQ_Flag__c like '%HQ%'),
              (select Id
               from Accounts2__r)
       from Account
       where Id in :allAccountIds]);

    // Part2: Approved Requests update to Accounts
    for (Account_Credit_Request__c acr : acrList) {
      Account a = accountMap.get(acr.Account__c);
      childAccounts = a.Accounts2__r;
      if (accountsToUpdateMap.containsKey(acr.Account__c)) {
        a = accountsToUpdateMap.get(acr.Account__c);
      }

      if (acr.Credit_App_Status__c == STATUS_APPROVED &&
        (oldMap == null ||
        !oldMap.containsKey(acr.Id) ||
        oldMap.get(acr.Id).Credit_App_Status__c != STATUS_APPROVED)) {

        a.Verification_Status__c = VERIFIED;

        if (acr.Proposed_Online_Credit_Limit__c == null && 
          acr.Proposed_Manual_Credit_Limit__c == null) {
          throw new BlankCreditLimitException(
            Label.ADS_Acct_Credit_Req_OnlineLimit_Required);
          return;
        }

        if (acr.Proposed_Online_Credit_Limit__c > 0 && 
          acr.Proposed_Manual_Credit_Limit__c > 0) {
          throw new BlankCreditLimitException(
            Label.ADS_Acct_Credit_Req_ManualLimit_Required);
          return;
        }

        if (acr.Proposed_Online_Credit_Limit__c > 0) {
          a.Online_Credit_Limit__c =
            acr.Proposed_Online_Credit_Limit__c.round(System.RoundingMode.DOWN);
        } else if (acr.Proposed_Manual_Credit_Limit__c > 0) {
          a.IO_Credit_Limit__c = 
            acr.Proposed_Manual_Credit_Limit__c.round(System.RoundingMode.DOWN);
        }

        a.Last_Credit_Evaluation__c = Date.today();
        a.Last_Evaluated_By__c = UserInfo.getUserId();
        a.Account_Credit_Request_Open__c = false;
        a.Suspended__c = acr.Suspend_Account__c;

        if (acr.RecordTypeId == approvedRTId) {
          if (a.Automatic_Credit_Increase_Count__c == null) {
            a.Automatic_Credit_Increase_Count__c = 0;
          }
          a.Automatic_Credit_Increase_Count__c =
            a.Automatic_Credit_Increase_Count__c + 1;
        } else if (acr.RecordTypeId == newRTId ||
          acr.RecordTypeId == newClosedRTId){

          if (acr.Form_Legal_Entity_Name__c != null) {
            a.Legal_Entity_Name__c = acr.Form_Legal_Entity_Name__c;
          }
          if (acr.Form_DUNS_Number__c != null) {
            a.DUNS_Number__c = acr.Form_DUNS_Number__c;
          }
          if (acr.Form_Tax_ID__c != null) {
             a.TAX_ID__c = acr.Form_Tax_ID__c;
          }
          if (acr.Form_CNPJ__c != null) {
            a.CNPJ_Brazil__c = acr.Form_CNPJ__c;
          }
          if (acr.Form_Company_Registration_Number__c != null) {
            a.Business_Reg_ID__c = acr.Form_Company_Registration_Number__c;
          }
          if (acr.Form_Country__c != 'BR') {
            for (Site__c address : a.Sites__r) {
              if (acr.Form_Address_1__c != null) {
                address.Address_Line_1__c = acr.Form_Address_1__c;
              }
              if (acr.Form_Address_2__c != null) {
                address.Address_Line_2__c = acr.Form_Address_2__c;
              }
              if (acr.Form_Address_1__c != null) {
                address.City__c = acr.Form_City__c;
              }
              if (acr.Form_Address_1__c != null) {
                address.State__c = acr.Form_State__c;
              }
              if (acr.Form_Address_1__c != null) {
                address.Postal_Code__c = acr.Form_Zip_Postal_Code__c;
              }
              if (acr.Form_Country__c != null) {
                address.Country__c = acr.Form_Country__c;
              }
              addressToUpdate.put(address.Id, address);
            }
          }
          if (acr.Form_Email_Address_for_Invoicing__c != null) {
            Contact con = new Contact();
            if (acr.Form_Email_Address_for_Invoicing__c != null) {
              con.Email = acr.Form_Email_Address_for_Invoicing__c;
            }
            if (acr.Form_Phone_Number__c != null) {
              con.Phone = acr.Form_Phone_Number__c;
            }
            con.AccountId = a.Id;
            con.LastName = 'Ap';
            contactsToInsert.add(con);
          }
        }

        accountsToUpdateMap.put(a.Id, a);
        updateChildAccounts(childAccounts, accountsToUpdateMap);
      } else if ((acr.Credit_App_Status__c == STATUS_EXPIRED ||
        acr.Credit_App_Status__c == STATUS_NEW_REJECTED) &&
        (oldMap == null ||
          !oldMap.containsKey(acr.Id) ||
          oldMap.get(acr.Id).Credit_App_Status__c != STATUS_REJECTED)) {

        a.Account_Credit_Request_Open__c = false;
        accountsToUpdateMap.put(a.Id, a);
      } else if (acr.Credit_App_Status__c == STATUS_REJECTED &&
        (oldMap == null ||
        !oldMap.containsKey(acr.Id) ||
        oldMap.get(acr.Id).Credit_App_Status__c != STATUS_REJECTED)) {

        a.Last_Credit_Evaluation__c = Date.today();
        a.Last_Evaluated_By__c = UserInfo.getUserId();
        a.Account_Credit_Request_Open__c = true;
        accountsToUpdateMap.put(a.Id, a);
        updateChildAccounts(childAccounts, accountsToUpdateMap);
      } else if (oldMap != null &&
          OPEN_CREDIT_REQUEST_STATUSES.contains(acr.Credit_App_Status__c)
          && !accountsToUpdateMap.containsKey(a.Id)) {

        a.Account_Credit_Request_Open__c = true;

        if (acr.TEMP_Online_Credit_Limit__c <> null &&
          (acr.TEMP_Online_Credit_Limit__c > a.Online_Credit_Limit__c)) {

          a.Online_Credit_Limit__c = acr.TEMP_Online_Credit_Limit__c;
          a.Last_Credit_Evaluation__c = Date.today();
          a.Last_Evaluated_By__c = UserInfo.getUserId();
          updateChildAccounts(childAccounts, accountsToUpdateMap);
        }

        accountsToUpdateMap.put(a.Id, a);
      } else if (oldMap != null && oldMap.containsKey(acr.Id) &&
        acr.Account__c != null && a.Account_Credit_Request_Open__c &&
        oldMap.get(acr.Id).Credit_App_Status__c != acr.Credit_App_Status__c &&
        acr.Credit_App_Status__c == 'Closed - Deprecated') {

        a.Account_Credit_Request_Open__c = false;
        accountsToUpdateMap.put(a.Id, a);
      }
    }

    // Account changed, update old account to false
    for (Account_Credit_Request__c acr : acrList) {
      Account_Credit_Request__c oldAcr = null;
      if (oldMap != null) {
        oldAcr = oldMap.get(acr.Id);
      } else {
        continue;
      }

      Account oldAct = new Account(Id = oldAcr.Account__c);

      if (oldMap != null && oldAcr.Account__c != null
        && oldAcr.Account__c != acr.Account__c
        && OPEN_CREDIT_REQUEST_STATUSES.contains(acr.Credit_App_Status__c)) {

        oldAct.Account_Credit_Request_Open__c = false;
        accountsToUpdateMap.put(oldAct.Id, oldAct);
      }
    }

    if (!accountsToUpdateMap.isEmpty()) {
      AccountManagement.shouldRun = false;
      shouldRun = false;
      update accountsToUpdateMap.values();
      shouldRun = true;
      AccountManagement.shouldRun = true;
    }
    if (!addressToUpdate.isEmpty()) {
      shouldRun = false;
      update addressToUpdate.values();
      shouldRun = true;
    }
    if (!contactsToInsert.isEmpty()) {
      ADS_ContactManagement.shouldRun = false;
      shouldRun = false;
      insert contactsToInsert;
      shouldRun = true;
      ADS_ContactManagement.shouldRun = true;

      List<Account_Contact_Role__c> acs = new List<Account_Contact_Role__c>();
      for (Contact con : contactsToInsert) {
        acs.add(New Account_Contact_Role__c(Contact__c = con.id,
          AccountId__c = con.AccountId, 
          Role__c = WP_Constants.ACC_CON_ROLE_WP_BILLING));
      }
      if (!acs.isEmpty()) {
        shouldRun = false;
        insert acs;
        shouldRun = true;
      }
    }
  }

  private static void autoSubmitForApproval(List<Account_Credit_Request__c>
    newAccCr, Map<Id, Account_Credit_Request__c> oldMap) {

    List<Approval.ProcessSubmitRequest> approvalRequets =
      new List<Approval.ProcessSubmitRequest>();

    for (Account_Credit_Request__c c : newAccCr) {
      Account_Credit_Request__c old = null;
      if (oldMap != null && oldMap.containsKey(c.Id)) {
        old = oldMap.get(c.Id);
      }

      if (c.RecordTypeId != approvedRTId &&
        !hasApprovalReqSubmittedInThisTxn && (
        (c.RecordTypeId != newRTId && old == null) ||
        (c.RecordTypeId == newRTId && old == null &&
          c.Credit_App_Status__c == STATUS_SUBMITTED &&
          (UserInfo.getUserId() == UNITY_BOT_ID ||
            c.WP_Application__c == true)) ||
        (c.RecordTypeId == newRTId && old != null &&
          c.Credit_App_Status__c != old.Credit_App_Status__c &&
          c.Credit_App_Status__c == STATUS_SUBMITTED &&
          c.CreatedById == UNITY_BOT_ID &&
          UserInfo.getUserId() == UNITY_BOT_ID))) {

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setComments('Submitted for approval. Please approve.');
        req.setObjectId(c.Id);
        approvalRequets.add(req);
        hasApprovalReqSubmittedInThisTxn = true;
        shouldRun = false;
        Approval.ProcessResult result = Approval.process(req);
        shouldRun = true;
      }
    }
  }

  private static void updateChildAccounts(List<Account> childAccounts,
    Map<Id, Account> accountsToUpdateMap) {

    for (Account a : childAccounts) {
      if (accountsToUpdateMap.containsKey(a.Id)) {
        a = accountsToUpdateMap.get(a.Id);
      }
      a.Last_Credit_Evaluation__c = Date.today();
      a.Last_Evaluated_By__c = UserInfo.getUserId();
      accountsToUpdateMap.put(a.Id, a);
    }
  }

  private static void getDunsForGDMReport(
    List<Account_Credit_Request__c> acrList) {

      Set<Id> acctIds = new Set<Id>();
      Map<Id, String> acctIdDunsMap = new Map<Id, String>();
      for (Account_Credit_Request__c acr : acrList) {
        if (acr.DUNS_Number__c != null
          && acr.RecordTypeId == increaseOpenRTId) {

          acctIds.add(acr.Account__c);
        }
      }
      if (!acctIds.isEmpty()) {
        for (Account acc : [select Id, LatestCreditReportInsert__c,
                                   DUNS_Number__c
                            from Account
                            where Id in :acctIds
                            and (LatestCreditReportInsert__c = null
                              or LatestCreditReportInsert__c
                                < LAST_N_MONTHS:6)
                            limit 100]) {

          acctIdDunsMap.put(acc.Id, acc.Duns_Number__c);
        }
        triggerGDMReportFuture(acctIdDunsMap);
      }
    }

  @future(callout = true)
  private static void triggerGDMReportFuture(
    Map<Id, String> acctIdDunsMap) {

    DNB_CreditCheckUtility.triggerGDMReport(acctIdDunsMap);
  }

  private class BlankCreditLimitException extends Exception{}
}