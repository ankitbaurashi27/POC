public class NoteTriggerHelper {
    
    public void deleteNoteJunctionRecords(List<Note__c> recordsToBeDeleted){
        try{
            Set<Id> idsToBeDeleted = new Set<Id>();
            if(recordsToBeDeleted != null && !recordsToBeDeleted.isEmpty()){
                for (Note__c note : recordsToBeDeleted){
                    idsToBeDeleted.add(note.Id);
                }
            }
            if(!idsToBeDeleted.isEmpty()){
                List<Note_Junction__c> getAssociatedRecords = [SELECT Id FROM Note_Junction__c WHERE Note__c IN :idsToBeDeleted];
                if(!getAssociatedRecords.isEmpty()){
                    delete getAssociatedRecords;
                }
            } 
        }catch(Exception ex){
            system.debug('Ex ==>' + ex.getMessage() + 'Stack ==>'+ ex.getStackTraceString());
        }      
    }
}