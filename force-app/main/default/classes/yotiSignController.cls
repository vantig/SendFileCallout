public with sharing class yotiSignController {
    @AuraEnabled(Cacheable = true)
    public static List<ContentVersion> getAttachments(String recordId) {
        List<Id> documentIds = new List<Id>();
        for (ContentDocumentLink documentLink : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :recordId]) {
            documentIds.add(documentLink.ContentDocumentId);
        }
        return [SELECT Title FROM ContentVersion WHERE ContentDocumentId IN :documentIds];
    }
    @AuraEnabled(Cacheable=true)
    public static List<SObject> search(String searchTerm, String myObject, String filter) {
        String myQuery = null;
        if (filter != null && filter != '') {
            myQuery = 'Select Id, Name from ' + myObject + ' Where Name Like  \'%' + searchTerm + '%\' AND ' + filter + ' LIMIT  5';
        } else {
            if (searchTerm == null || searchTerm == '') {
                myQuery = 'Select Id, Name from ' + myObject + ' Where LastViewedDate != NULL ORDER BY LastViewedDate DESC LIMIT  5';
            } else {
                myQuery = 'Select Id, Name from ' + myObject + ' Where Name Like  \'%' + searchTerm + '%\' LIMIT  5';
            }
        }
        List<SObject> lookUpList = Database.query(myQuery);
        return lookUpList;
    }
    public static Blob getFileAsBlob(Blob file_body, String file_name) {
        // Repost of code  with fix for file corruption issue
        // Orignal code postings and explanations
        // http://enreeco.blogspot.in/2013/01/salesforce-apex-post-mutipartform-data.html
        // http://salesforce.stackexchange.com/questions/24108/post-multipart-without-base64-encoding-the-body
        // Additional changes commented GW: that fix issue with occasional corruption of files
        String boundary = '----------------------------741e90d31eff';
        String header = '--' + boundary + '\nContent-Disposition: form-data; name="file"; filename="' + file_name + '";\nContent-Type: application/octet-stream';
        // GW: Do not prepend footer with \r\n, you'll see why in a moment
        // String footer = '\r\n--'+boundary+'--';
        String footer = '--' + boundary + '--';
        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
        while (headerEncoded.endsWith('=')) {
            header += ' ';
            headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header + '\r\n\r\n'));
        }
        String bodyEncoded = EncodingUtil.base64Encode(file_body);
        // GW: Do not encode footer yet
        // String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));

        Blob bodyBlob = null;
        String last4Bytes = bodyEncoded.substring(bodyEncoded.length() - 4, bodyEncoded.length());

        // GW: Replacing this entire section
        /*
        if(last4Bytes.endsWith('='))
        {
             Blob decoded4Bytes = EncodingUtil.base64Decode(last4Bytes);
             HttpRequest tmp = new HttpRequest();
             tmp.setBodyAsBlob(decoded4Bytes);
             String last4BytesFooter = tmp.getBody()+footer;
             bodyBlob = EncodingUtil.base64Decode(headerEncoded+bodyEncoded.substring(0,bodyEncoded.length()-4)+EncodingUtil.base64Encode(Blob.valueOf(last4BytesFooter)));
        }
        else
        {
              bodyBlob = EncodingUtil.base64Decode(headerEncoded+bodyEncoded+footerEncoded);
        }
        */
        // GW: replacement section to get rid of padding without corrupting data
        if (last4Bytes.endsWith('==')) {
            // The '==' sequence indicates that the last group contained only one 8 bit byte
            // 8 digit binary representation of CR is 00001101
            // 8 digit binary representation of LF is 00001010
            // Stitch them together and then from the right split them into 6 bit chunks
            // 0000110100001010 becomes 0000 110100 001010
            // Note the first 4 bits 0000 are identical to the padding used to encode the
            // second original 6 bit chunk, this is handy it means we can hard code the response in
            // The decimal values of 110100 001010 are 52 10
            // The base64 mapping values of 52 10 are 0 K
            // See http://en.wikipedia.org/wiki/Base64 for base64 mapping table
            // Therefore, we replace == with 0K
            // Note: if using \n\n instead of \r\n replace == with 'oK'
            last4Bytes = last4Bytes.substring(0, 2) + '0K';
            bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
            // We have appended the \r\n to the Blob, so leave footer as it is.
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + footerEncoded);
        } else if (last4Bytes.endsWith('=')) {
            // '=' indicates that encoded data already contained two out of 3x 8 bit bytes
            // We replace final 8 bit byte with a CR e.g. \r
            // 8 digit binary representation of CR is 00001101
            // Ignore the first 2 bits of 00 001101 they have already been used up as padding
            // for the existing data.
            // The Decimal value of 001101 is 13
            // The base64 value of 13 is N
            // Therefore, we replace = with N
            // Note: if using \n instead of \r replace = with 'K'
            last4Bytes = last4Bytes.substring(0, 3) + 'N';
            bodyEncoded = bodyEncoded.substring(0, bodyEncoded.length() - 4) + last4Bytes;
            // We have appended the CR e.g. \r, still need to prepend the line feed to the footer
            footer = '\n' + footer;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + footerEncoded);
        } else {
            // Prepend the CR LF to the footer
            footer = '\r\n' + footer;
            String footerEncoded = EncodingUtil.base64Encode(Blob.valueOf(footer));
            bodyBlob = EncodingUtil.base64Decode(headerEncoded + bodyEncoded + footerEncoded);
        }

        return bodyBlob;
    }
    @AuraEnabled
    public static String yotisignRequest(String userId, List<String> documentIds) {
        System.debug('userId ' + userId);
        System.debug('documentIds ' + documentIds);
        //List<String>documents = (List<String>) JSON.deserialize(documentIds, List<String>.class);
//       List<ContentVersion>files = new List<ContentVersion>([SELECT VersionData,Title FROM ContentVersion WHERE Id IN :documents]) ;
        ContentVersion file = [SELECT VersionData,Title FROM ContentVersion WHERE Id IN :documentIds LIMIT 1] ;
        User usr = [SELECT Name,Email FROM User WHERE Id = :userId];
        final String APIKEY = '';
        String boundary = '----------------------------741e90d31eff';


        HttpRequest request = new HttpRequest();


        YotiOptions options = new YotiOptions();
        YotiOptions.Tag tag = new YotiOptions.Tag();
        tag.file_name = file.Title;
        options.recipients = new List<YotiOptions.Recipient>{
                new YotiOptions.Recipient(usr.Name, usr.Email, new List<YotiOptions.Tag>{
                        tag
                })
        };
        YotiCallout yotiCallout = new YotiCallout();
        yotiCallout.file = file.VersionData;
        yotiCallout.options = options;
//        request.setBody('{"file":' + getFileAsBlob(files[0].VersionData, files[0].Title) + ',"options" : {\n' +
//                '    "name": "envelope name",\n' +
//                '    "emails": {\n' +
//                '        "invitation": {\n' +
//                '            "body": {\n' +
//                '                "message": "Please sign this document"\n' +
//                '            }\n' +
//                '        },\n' +
//                '      "reminders": {\n' +
//                '          "frequency": 1\n' +
//                '      }\n' +
//                '    },\n' +
//                '    "has_envelope_otps": true,\n' +
//                '    "recipients": [\n' +
//                '        {\n' +
//                '            "name": ' + usr.Name +
//                '            "email":' + usr.Email +
//                '            "role": "Signee",\n' +
//                '            "auth_type": "no-auth", \n' +
//                '            "sign_group": 1,\n' +
//                '            "tags": [\n' +
//                '                {\n' +
//                '                    "page_number": 1,\n' +
//                '                    "x": 0.1,\n' +
//                '                    "y": 0.1,\n' +
//                '                    "type": "signature",\n' +
//                '                    "optional": false,\n' +
//                '                    "file_name": "myfile.pdf"\n' +
//                '                }\n' +
//                '            ],\n' +
//                '            "country_code": "GB",\n' +
//                '            "phone_number": "7999999999",\n' +
//                '            "witness": {\n' +
//                '              "tags": [\n' +
//                '                ...\n' +
//                '              ]\n' +
//                '            }\n' +
//                '        }\n' +
//                '    ],\n' +
//                '    "notifications": {\n' +
//                '        "destination": "https://mysite.com/events",\n' +
//                '        "subscriptions": [\n' +
//                '            "envelope_completion"\n' +
//                '        ]\n' +
//                '    }\n' +
//                '} }');
        request.setBodyAsBlob(Blob.valueOf(JSON.serialize(yotiCallout)));
        return JSON.serialize(yotiCallout);
//        request.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
//        request.setHeader('Authorization', 'Bearer ' + APIKEY);
//        request.setEndpoint('callout:yotisignDemo');
//        request.setMethod('POST');
//        Http http = new Http();
//        HttpResponse response = http.send(request);
//
//        if (response.getStatusCode() == 202 || response.getStatusCode() == 200) {
//            return response.getBody();
//        }
//        return null;
    }
}