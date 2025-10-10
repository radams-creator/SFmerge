public with sharing class TaxLetterService {
    public class MergeRequest {
        @AuraEnabled public Id reportId;
        @AuraEnabled public Id templateContentDocumentId;
        @AuraEnabled public String deliveryOption; // EMAIL or FILE
        @AuraEnabled public Boolean previewOnly;
    }

    public class MergePreview {
        @AuraEnabled public String letterBody;
        @AuraEnabled public Map<String, String> tokens;
        @AuraEnabled public Integer recordCount;
    }

    @AuraEnabled(cacheable=true)
    public static MergePreview previewMerge(MergeRequest request) {
        validateRequest(request);
        Reports.ReportResults results = Reports.ReportManager.runReport(request.reportId, true);
        List<Map<String, String>> rows = normaliseReportRows(results);
        if (rows.isEmpty()) {
            return new MergePreview();
        }
        String template = loadTemplate(request.templateContentDocumentId);
        Map<String, String> firstRow = rows[0];
        MergePreview preview = new MergePreview();
        preview.tokens = firstRow;
        preview.recordCount = rows.size();
        preview.letterBody = applyTemplate(template, firstRow);
        return preview;
    }

    @AuraEnabled
    public static List<Id> generateLetters(MergeRequest request) {
        validateRequest(request);
        Reports.ReportResults results = Reports.ReportManager.runReport(request.reportId, true);
        List<Map<String, String>> rows = normaliseReportRows(results);
        if (rows.isEmpty()) {
            return new List<Id>();
        }
        String template = loadTemplate(request.templateContentDocumentId);
        List<Id> generatedContentIds = new List<Id>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Map<String, String> row : rows) {
            String rendered = applyTemplate(template, row);
            ContentVersion version = persistLetter(rendered, row);
            generatedContentIds.add(version.ContentDocumentId);

            if ('EMAIL'.equalsIgnoreCase(request.deliveryOption)) {
                Messaging.SingleEmailMessage email = buildEmail(version, row);
                if (email != null) {
                    emails.add(email);
                }
            }
        }

        if (!emails.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails, false);
            handleEmailErrors(results);
        }
        return generatedContentIds;
    }

    private static void validateRequest(MergeRequest request) {
        if (request == null) {
            throw new AuraHandledException('Request is required.');
        }
        if (request.reportId == null) {
            throw new AuraHandledException('A report must be selected.');
        }
        if (request.templateContentDocumentId == null) {
            throw new AuraHandledException('A template file must be selected.');
        }
    }

    @TestVisible
    private static List<Map<String, String>> normaliseReportRows(Reports.ReportResults results) {
        if (results == null || results.getFactMap() == null) {
            return new List<Map<String, String>>();
        }
        Map<String, Reports.ReportFactWithDetails> factMap = results.getFactMap();
        if (factMap == null || factMap.isEmpty()) {
            return new List<Map<String, String>>();
        }
        List<Reports.ReportFactWithDetailsRow> detailRows = new List<Reports.ReportFactWithDetailsRow>();
        for (String key : factMap.keySet()) {
            if (key.endsWith('!T')) {
                Reports.ReportFactWithDetails detailFact = factMap.get(key);
                if (detailFact != null && detailFact.getRows() != null) {
                    detailRows.addAll(detailFact.getRows());
                }
            }
        }
        if (detailRows.isEmpty()) {
            return new List<Map<String, String>>();
        }
        List<String> detailColumns = results.getReportMetadata() != null
            ? results.getReportMetadata().getDetailColumns()
            : new List<String>();
        Map<String, Object> columnInfo = new Map<String, Object>();
        Reports.ReportExtendedMetadata extended = results.getReportExtendedMetadata();
        if (extended != null) {
            columnInfo = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(extended.getDetailColumnInfo()));
        }
        List<String> labels = new List<String>();
        for (String columnName : detailColumns) {
            String label = columnName;
            if (columnInfo.containsKey(columnName)) {
                Map<String, Object> columnMap = (Map<String, Object>)columnInfo.get(columnName);
                if (columnMap != null && columnMap.containsKey('label') && columnMap.get('label') != null) {
                    label = String.valueOf(columnMap.get('label'));
                }
            }
            labels.add(sanitiseToken(label));
        }
        List<Map<String, String>> output = new List<Map<String, String>>();
        for (Reports.ReportFactWithDetailsRow row : detailRows) {
            List<Reports.ReportDataCell> dataCells = row.getDataCells();
            Map<String, String> tokenValues = new Map<String, String>();
            Integer index = 0;
            for (Reports.ReportDataCell cell : dataCells) {
                if (index >= labels.size()) {
                    break;
                }
                String label = labels[index];
                String value = cell.getLabel() != null
                    ? cell.getLabel()
                    : (cell.getValue() != null ? String.valueOf(cell.getValue()) : '');
                tokenValues.put(label, value);
                index++;
            }
            output.add(tokenValues);
        }
        return output;
    }

    private static String loadTemplate(Id contentDocumentId) {
        ContentVersion version = [
            SELECT Id, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY IsLatest DESC, CreatedDate DESC
            LIMIT 1
        ];
        Blob data = version.VersionData;
        if (data == null) {
            throw new AuraHandledException('Template file has no content.');
        }
        return data.toString();
    }

    @TestVisible
    private static String applyTemplate(String template, Map<String, String> tokens) {
        String output = template;
        for (String key : tokens.keySet()) {
            String token = '{{' + key + '}}';
            output = output.replace(token, tokens.get(key));
        }
        return output;
    }

    private static ContentVersion persistLetter(String body, Map<String, String> row) {
        String fileName = row.containsKey('Contact_Name')
            ? row.get('Contact_Name') + ' Tax Letter.html'
            : 'Tax Letter.html';
        ContentVersion version = new ContentVersion();
        version.Title = fileName;
        version.PathOnClient = fileName;
        version.VersionData = Blob.valueOf(body);
        insert version;
        return version;
    }

    private static Messaging.SingleEmailMessage buildEmail(ContentVersion version, Map<String, String> row) {
        if (!row.containsKey('Contact_Email')) {
            return null;
        }
        String emailAddress = row.get('Contact_Email');
        if (String.isBlank(emailAddress)) {
            return null;
        }
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(version.Title);
        attachment.setBody(version.VersionData);

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ emailAddress });
        if (row.containsKey('Contact_Name')) {
            email.setSubject('Thank you, ' + row.get('Contact_Name'));
        } else {
            email.setSubject('Thank you for your contribution');
        }
        email.setPlainTextBody('Please find your tax acknowledgement letter attached.');
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
        return email;
    }

    private static void handleEmailErrors(Messaging.SendEmailResult[] results) {
        List<String> errors = new List<String>();
        for (Messaging.SendEmailResult result : results) {
            if (!result.isSuccess()) {
                for (Messaging.SendEmailError error : result.getErrors()) {
                    errors.add(error.getStatusCode() + ': ' + error.getMessage());
                }
            }
        }
        if (!errors.isEmpty()) {
            throw new AuraHandledException('Email dispatch failed: ' + String.join(errors, '; '));
        }
    }

    @TestVisible
    private static String sanitiseToken(String label) {
        if (label == null) {
            return '';
        }
        return label.replaceAll('[^A-Za-z0-9]', '_');
    }
}
