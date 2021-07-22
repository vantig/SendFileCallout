import {LightningElement, api, wire} from 'lwc';
import {getRecord} from 'lightning/uiRecordApi';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import NAME_FIELD from '@salesforce/schema/User.Name';

import getAttachments from '@salesforce/apex/yotiSignController.getAttachments';
import yotisignRequest from '@salesforce/apex/yotiSignController.yotisignRequest';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

const columns = [
    {label: 'File Name', fieldName: 'Title'},
];
export default class YotiSign extends LightningElement {
    isDocumentsTemplate = true;
    isSelectAttachmentTemplate = false;
    isSignersTemplate = false;
    attachments;
    selectedAttachmentsIds = [];
    columns = columns;
    userId = null;
    isLoading = false;
    @api recordId;
    // @wire(getRecord, {recordId: '$userId', fields: [NAME_FIELD, EMAIL_FIELD]})
    // user;

    @wire(getAttachments, {recordId: '$recordId'})
    wiredRecordsMethod({error, data}) {
        if (data) {
            this.attachments = data;
        } else if (error) {
            this.attachments = undefined;
            let evt = new ShowToastEvent({
                variant: "error",
                message: error.message
            });
            this.dispatchEvent(evt);
        }

    }

    handleNextFromSignersClick() {

        if (this.userId == null) {
            let evt = new ShowToastEvent({
                variant: "warning",
                message: "Select User"
            });
            this.dispatchEvent(evt);
            return;
        }
        this.isLoading = true;
        this.isSignersTemplate = false;
        this.isDocumentsTemplate = true;
        console.log("userId " + this.userId, "selectedAttachmentsIds " + this.selectedAttachmentsIds);
        yotisignRequest({userId: this.userId, documentIds: this.selectedAttachmentsIds}).then(response => {
            this.isLoading = false;
            console.log(JSON.stringify(response) + " success");
            let evt = new ShowToastEvent({
                variant: "success",
                message: JSON.stringify(response)
            });
            this.dispatchEvent(evt);
        }).catch(error => {
            this.isLoading = false;
            console.log(JSON.stringify(error) + " errrrrror");
            let evt = new ShowToastEvent({
                variant: "error",
                message: error.body.message
            });
            this.dispatchEvent(evt);
        });

        this.userId = null;
        this.selectedAttachmentsIds = [];

    }

    handleRowSelection(event) {
        this.selectedAttachmentsIds = [];
        event.detail.selectedRows.forEach(row => this.selectedAttachmentsIds.push(row.Id));
        console.log(this.selectedAttachmentsIds);

    }

    handleSelectFileFromAttachmentsClick(event) {
        this.isDocumentsTemplate = false;
        this.isSelectAttachmentTemplate = true;
    }

    handleNextFromAttachmentsListClick(event) {
        if (this.selectedAttachmentsIds.length < 1) {
            let evt = new ShowToastEvent({
                variant: "warning",
                message: "Select at least 1 file"
            });
            this.dispatchEvent(evt);
        } else {
            this.isSelectAttachmentTemplate = false;
            this.isSignersTemplate = true;
        }

    }

    handleUserSelection(event) {
        this.userId = event.detail;
    }
}