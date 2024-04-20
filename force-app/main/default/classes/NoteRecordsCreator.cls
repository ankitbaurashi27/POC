public class NoteRecordsCreator {
	@InvocableMethod(label='Create Note Record')
    public static List<String> createNoteRecords(List<NotesWrapper> noteWrappers){
        try{
            if(noteWrappers.isEmpty()){ 
                return new List<String>{'No Input Found !'}; 
            }
			NotesWrapper noteWrapper = noteWrappers[0];
            List<Note_Junction__c> noteJunctionRecordsToInsert = new List<Note_Junction__c>();
            Note__c noteRecord = noteWrapper.noteRecord;
			insert noteRecord;
    		
            if(noteWrapper.opportunityIds != null){
             	for(Integer i = 0; i < noteWrapper.opportunityIds.size(); i++){
                    Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                    noteJunctionRecord.Note__c = noteRecord.Id;
                    noteJunctionRecord.Opportunity__c = noteWrapper.opportunityIds[i];
                    noteJunctionRecordsToInsert.add(noteJunctionRecord);
            	}   
            }

			if(noteWrapper.accountIds != null){
             	for(Integer i = 0; i < noteWrapper.accountIds.size(); i++){
                    Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                    noteJunctionRecord.Note__c = noteRecord.Id;
                    noteJunctionRecord.Account__c = noteWrapper.accountIds[i];
                    noteJunctionRecordsToInsert.add(noteJunctionRecord);
            	} 
            }
            
           if(noteWrapper.contactIds != null){
             	for(Integer i = 0; i < noteWrapper.contactIds.size(); i++){
                    Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                    noteJunctionRecord.Note__c = noteRecord.Id;
                    noteJunctionRecord.Contact__c = noteWrapper.contactIds[i];
                    noteJunctionRecordsToInsert.add(noteJunctionRecord);
            	}
            }

            if(noteWrapper.tradingModelIds != null){
             	for(Integer i = 0; i < noteWrapper.tradingModelIds.size(); i++){
                    Note_Junction__c noteJunctionRecord = new Note_Junction__c();	
                    noteJunctionRecord.Note__c = noteRecord.Id;
                    noteJunctionRecord.Trading_Model__c = noteWrapper.tradingModelIds[i];
                    noteJunctionRecordsToInsert.add(noteJunctionRecord);
            	}
            }

            if(!noteJunctionRecordsToInsert.isEmpty()){ 
                INSERT noteJunctionRecordsToInsert;
            }
            return new List<String>{'Note Records Inserted Successfully !'};
        }catch(Exception ex){
			system.debug('stack ==>'+ ex.getStackTraceString());
            return new List<String>{ex.getMessage()};
        }
    }
    
}