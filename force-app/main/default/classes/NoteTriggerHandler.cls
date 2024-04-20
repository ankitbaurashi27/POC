public class NoteTriggerHandler {
    NoteTriggerHelper helper = new NoteTriggerHelper();

    public void run(){
        switch on Trigger.operationType {
            when AFTER_DELETE {
                afterDelete(Trigger.old);
            }
            when AFTER_UNDELETE {
                afterUndelete(trigger.new);
            }
        }
    } 

    public void afterDelete(List<Note__c> records){
        helper.deleteNoteAndNoteJunctionRecords(records);
    }

    public void afterUndelete(List<Note__c> records){
        helper.undeleteNoteJunctionRecords(records);
    }

}
