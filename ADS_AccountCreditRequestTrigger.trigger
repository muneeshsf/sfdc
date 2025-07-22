trigger ADS_AccountCreditRequestTrigger on Account_Credit_Request__c (
  after insert, after update, after delete, after undelete, before insert,
  before update) {

  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      ADS_AccountCreditRequestManagement.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore) {
      ADS_AccountCreditRequestManagement.beforeUpdate(Trigger.new,
        Trigger.oldMap);
    }
  } else {
    if (Trigger.isInsert) {
      ADS_AccountCreditRequestManagement.afterInsert(Trigger.new);
    } else if (Trigger.isUpdate) {
      ADS_AccountCreditRequestManagement.afterUpdate(Trigger.new,
        Trigger.oldMap);
    } else if (Trigger.isDelete) {
      ADS_AccountCreditRequestManagement.afterDelete(Trigger.old);
    } else if (Trigger.isUndelete) {
      ADS_AccountCreditRequestManagement.afterUndelete(Trigger.new);
    }
  }

  new UnitySyncObserver();
}