public class NotesWrapper {
    public NotesWrapper(){}
    @InvocableVariable @AuraEnabled 
    public List<String> opportunityIds;
    
    @InvocableVariable @AuraEnabled 
    public List<String> contactIds;
    
    @InvocableVariable @AuraEnabled 
    public List<String> accountIds;

    @InvocableVariable @AuraEnabled 
    public List<String> tradingModelIds;
    
    @InvocableVariable @AuraEnabled 
    public Note__c noteRecord;
}