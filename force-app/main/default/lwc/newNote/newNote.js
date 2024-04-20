import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import NOTE from "@salesforce/schema/Note__c";
import NAME from '@salesforce/schema/Note__c.Name';
import CATEGORY from '@salesforce/schema/Note__c.Category_Id__c';
import NOTE_SUBJ from '@salesforce/schema/Note__c.Note_Subject__c';
import OPPORUTNITY from '@salesforce/schema/Note__c.Opportunity__c';
import CONTACT from '@salesforce/schema/Note__c.Contact__c';
import NOTE_SUBTYPE from '@salesforce/schema/Note__c.Note_Subtype__c';
import ACCOUNT from '@salesforce/schema/Note__c.Account__c';
import DESC from '@salesforce/schema/Note__c.Description__c';
import DATE from '@salesforce/schema/Note__c.Date__c';
import TRADING_MODEL from '@salesforce/schema/Note__c.Trading_Model__c';
import HIGH_IMP from '@salesforce/schema/Note__c.High_Importance__c';

export default class NewNote extends LightningElement {

    @api recordId;
    objectAPIName = NOTE;
    subj = NAME;
    category = CATEGORY;
    noteSubj = NOTE_SUBJ;
    opp = OPPORUTNITY;
    contact = CONTACT;
    noteSubType = NOTE_SUBTYPE;
    date = DATE;
    account = ACCOUNT;
    description = DESC;
    tradingModel = TRADING_MODEL;
    highImp = HIGH_IMP;
    activeSectionsMessage = '';
    activeSections = ['Information','Description'];

    handleSave(){
        console.log('inside save');
    }


    handleSectionToggle(event) {
        const openSections = event.detail.openSections;

        if (openSections.length === 0) {
            this.activeSectionsMessage = 'All sections are closed';
        } else {
            this.activeSectionsMessage =
                'Open sections: ' + openSections.join(', ');
        }
    }
}