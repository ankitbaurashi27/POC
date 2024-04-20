public class EditNoteRecord {
	@InvocableMethod(label='Edit Note Record')
    public static List<String> editNoteRecord(List<NotesWrapper> noteWrappers){
        try{        
            Set<Id> previousOppIds = new Set<Id>();
            Set<Id> previousAccIds = new Set<Id>();
            Set<Id> previousContactIds = new Set<Id>();
            Set<Id> noteJncToBeDeleted = new Set<Id>();
            Set<Id> perviousTradingIds = new Set<Id>();

            if(noteWrappers.isEmpty()){ 
                return new List<String>{'No input found.'};
            }

            NotesWrapper noteWrapper = noteWrappers[0];

            List<Note_Junction__c> noteJunctionRecordsToInsert = new List<Note_Junction__c>();
            Note__c noteRecord = noteWrapper.noteRecord;

            String noteRecordId = noteWrapper.noteRecord.Id;
            List<Note_Junction__c> noteJncRecords = getPreviousRecords(noteRecordId);

            for(Note_Junction__c noteJn: noteJncRecords){
                if(noteJn.Opportunity__c != null){
                	previousOppIds.add(noteJn.Opportunity__c);
                }
                if(noteJn.Account__c != null){
                	previousAccIds.add(noteJn.Account__c);
                }
				if(noteJn.Contact__c != null){
                	previousContactIds.add(noteJn.Contact__c);
                }
				if(noteJn.Trading_Model__c != null){
                	perviousTradingIds.add(noteJn.Trading_Model__c);
            }
            
            Set<Id> newOppIds = new Set<Id>();
            if(noteWrapper.opportunityIds != null){
                for(Integer i = 0; i < noteWrapper.opportunityIds.size(); i++){
                    newOppIds.add(noteWrapper.opportunityIds[i]);
                    if((!previousOppIds.isEmpty() && !previousOppIds.contains(noteWrapper.opportunityIds[i])) || previousOppIds.isEmpty()){
                        Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                        noteJunctionRecord.Note__c = noteRecord.Id;
                        noteJunctionRecord.Opportunity__c = noteWrapper.opportunityIds[i];
                        noteJunctionRecordsToInsert.add(noteJunctionRecord);
                    }
                }   
            }
                
            Set<Id> newContactIds = new Set<Id>();
            if(noteWrapper.contactIds != null){
                for(Integer i = 0; i < noteWrapper.contactIds.size(); i++){
                    newContactIds.add(noteWrapper.contactIds[i]);
                    if((!previousContactIds.isEmpty() && !previousContactIds.contains(noteWrapper.contactIds[i])) || previousContactIds.isEmpty()){
                        Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                        noteJunctionRecord.Note__c = noteRecord.Id;
                        noteJunctionRecord.Contact__c = noteWrapper.contactIds[i];
                        noteJunctionRecordsToInsert.add(noteJunctionRecord);
                    }
                }   
            }

            Set<Id> newAccountIds = new Set<Id>();
            if(noteWrapper.accountIds != null){
                for(Integer i = 0; i < noteWrapper.accountIds.size(); i++){
                    newAccountIds.add(noteWrapper.accountIds[i]);
                    if((!previousAccIds.isEmpty() &&!previousAccIds.contains(noteWrapper.accountIds[i])) || previousAccIds.isEmpty()){
                        Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                        noteJunctionRecord.Note__c = noteRecord.Id;
                        noteJunctionRecord.Account__c = noteWrapper.accountIds[i];
                        noteJunctionRecordsToInsert.add(noteJunctionRecord);
                    }
                }   
            }           
            
            Set<Id> newTradingIds = new Set<Id>();
            if(noteWrapper.tradingModelIds != null){
                for(Integer i = 0; i < noteWrapper.tradingModelIds.size(); i++){
                    newTradingIds.add(noteWrapper.tradingModelIds[i]);
                    if((!perviousTradingIds.isEmpty() && !perviousTradingIds.contains(noteWrapper.tradingModelIds[i])) || perviousTradingIds.isEmpty()){
                        Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                        noteJunctionRecord.Note__c = noteRecord.Id;
                        noteJunctionRecord.Trading_Model__c = noteWrapper.tradingModelIds[i];
                        noteJunctionRecordsToInsert.add(noteJunctionRecord);
                    }
                }   
            }           
                
            for(Id prvId :previousOppIds ){
                if(!newOppIds.contains(prvId)){
                    noteJncToBeDeleted.add(prvId);
                }
            }

            for(Id prvId :previousContactIds ){
                if(!newContactIds.contains(prvId)){
                    noteJncToBeDeleted.add(prvId);
                }
            }

            for(Id prvId :previousAccIds ){
                if(!newAccountIds.contains(prvId)){
                    noteJncToBeDeleted.add(prvId);
                }
            }

            for(Id prvId :perviousTradingIds ){
                if(!newTradingIds.contains(prvId)){
                    noteJncToBeDeleted.add(prvId);
                }
            }
            
            if(noteJncToBeDeleted != null && !noteJncToBeDeleted.isEmpty() ){
                List<Note_Junction__c> noteJunctionRecordsToDeleteForOpp = [SELECT Id FROM Note_Junction__c WHERE 
                                                                            Opportunity__c IN :noteJncToBeDeleted OR
                                                                            Contact__c IN :noteJncToBeDeleted OR 
                                                                            Account__c IN :noteJncToBeDeleted OR
                                                                            Trading_Model__c IN :noteJncToBeDeleted];
                
                if(!noteJunctionRecordsToDeleteForOpp.isEmpty()){
                    delete noteJunctionRecordsToDeleteForOpp;
                }
            }
        
            if(!noteJunctionRecordsToInsert.isEmpty()){
                insert noteJunctionRecordsToInsert;
            }
            
            return new List<String>{'Note Records Edited Successfully!'};
        }catch(Exception e){
            System.debug('Exception ==>' + e.getMessage());
            return new List<String>{e.getMessage()};
        }
    }
    
    public static List<Note_Junction__c> getPreviousRecords(String noteRecordId){
        if(String.isBlank(noteRecordId)){
            return null;
        }
        List<Note_Junction__c> noteJncRecords = [ SELECT Id, Note__c, Opportunity__r.Id,Contact__r.Id,Account__r.Id,Trading_Model__r.Id FROM Note_Junction__c WHERE Note__c = :noteRecordId ];
        return noteJncRecords;
	}
}