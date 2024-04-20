import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRelatedNoteRecords from '@salesforce/apex/DynamicRelatedListController.getRelatedNoteRecords';
import deleteRecord from '@salesforce/apex/DynamicRelatedListController.deleteRecord';

const actions = [
    { label: 'Show details', name: 'show_details' },
    { label: 'Delete', name: 'delete' },
];

const columns = [
    { label: 'Subject', fieldName: 'Name' },
    { label: 'Description', fieldName: 'Description__c'},
    { label: 'Date', fieldName: 'Date__c'},
    { label: 'High Importance', fieldName: 'High_Importance__c', type: 'checkbox'},
    {
        type: 'action',
        typeAttributes: { rowActions: actions },
    },
];

export default class DynamicRelatedList extends NavigationMixin(LightningElement) {
    @track data = [];
    @track strippedData =[];
    columns = columns;
    @api recordId;
    showTable = true;
    numberOfRecords;
    runflow = false;
    openModal = false;
    editNote = false;
    total;
    title;

    connectedCallback() {
        this.getNoteRecords(true);
        console.log('record ID ' +  this.recordId);
    }

    //pass input variables to the flow when component is loaded
    get inputVariables() {
        return [
            {
                name: 'recordId',
                type: 'String',
                value: this.noteRecordId
            }
        ];
    }

    get inputVariablesForNewNote(){
        return [
            {
                name: 'oppId',
                type: 'String',
                value: this.recordId
            },
            {
                name: 'accountId',
                type: 'String',
                value: this.recordId
            },
            {
                name: 'contactId',
                type: 'String',
                value: this.recordId
            }
        ];
    }

    
    getNoteRecords(isLimited){
        getRelatedNoteRecords({ recordId : this.recordId})
        .then(result =>{
            const NO_RECORD_FOUND = 'No Records Found';
            if(result && result != NO_RECORD_FOUND){
                const resultArray = JSON.parse(result);
                let numberOfNotes;
                this.total = resultArray.length;
                this.title = 'Notes  '+'('+resultArray.length+')';
                if(isLimited){
                    if(resultArray.length >= 5){
                        numberOfNotes =5;
                    }else{
                        numberOfNotes = resultArray.length
                    }
                   
                }
                if(!isLimited){
                    numberOfNotes = resultArray.length
                }

                this.strippedData =[];
                this.data =[];
                for (let i = 0; i < numberOfNotes; i++) {
                    const note = resultArray[i];
                    if (note.Description__c) {
                        const strippedNote = {
                            ...note,
                            Description__c: this.stripHtmlTags(note.Description__c)
                        };
                        if (strippedNote.Date__c) {
                            strippedNote.Date__c = this.formatDate(strippedNote.Date__c);
                        }
                        this.strippedData.push(strippedNote);
                    } else {
                        if (note.Date__c) {
                            note.Date__c = this.formatDate(note.Date__c);
                        }
                        this.strippedData.push(note);
                    }
                }
                this.data = this.strippedData;
            }else if(result && result == NO_RECORD_FOUND){
                this.showTable = false;
            }
        })
        .catch(exception =>{
            console.log(exception);
        })
    }

    stripHtmlTags(htmlString) {
        return htmlString.replace(/<\/?[^>]+(>|$)/g, "");
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        switch (actionName) {
            case 'delete':
                this.deleteRow(row);
                break;
            case 'show_details':
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: row.Id,
                        actionName: 'view'
                    }
                });
                break;
            default:
        }
    }

    deleteRow(row) {
        deleteRecord({noteRecordId : row.Id, objectRecordId : this.recordId})
        .then(result=> {
            if(result && result =='Success'){
                this.showToast(result, 'Note Deleted successfully !', 'Success');
                this.getNoteRecords(true);          
            }else{
                this.showToast('Error', result, 'Error');
            }
        })
        .catch(exception=> {
            console.log(exception);
        })
    }

    showToast(title,message,variant){
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
    handleMenuSelect(event){
        this.runflow = true;
    }

    closeModal(event){
        this.getNoteRecords(true);
        this.openModal = false;
        this.runflow = false;
        this.editNote = false;
    }
    handleAllButtonClick(){
        this.openModal = true;
        this.getNoteRecords(false);
    }
    navigateToRecord(event){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                "recordId": event.currentTarget.dataset.id,
                "objectApiName": "Note__c",
                "actionName": "view"
            },
        });
    }

    formatDate(dateString) {
        const date = new Date(dateString);
        const month = date.getMonth() + 1; 
        const day = date.getDate();
        const year = date.getFullYear();
        return `${month}/${day}/${year}`;
    }

    handleActionsMenuSelect(event){
        this.noteRecordId = event.currentTarget.dataset.id;
        const selectedValue = event.detail.value;
        if(selectedValue == 'Edit' ){
            this.editNote = true;
        }else if(selectedValue == 'Delete'){
            deleteRecord({noteRecordId : this.noteRecordId, objectRecordId : this.recordId})
            .then(result=> {
                if(result && result =='Success'){
                    this.showToast(result, 'Note Deleted successfully !', 'Success');
                    this.getNoteRecords(true);          
                }else{
                    this.showToast('Error', result, 'Error');
                }
            })
            .catch(exception=> {
                console.log(exception);
            })
        }
    }

    handleStatusChange(event){
        if (event.detail.interviewStatus === 'FINISHED') {
            this.getNoteRecords(true);
            this.editNote = false;
        }
        if (event.detail.errors) {
            this.showToast('Error !', event.detail.errors, 'error');
        }
    }
}