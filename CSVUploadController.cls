public with sharing class CSVUploadController {
    @AuraEnabled
    public static void uploadCSV(String csvContent, Id accountId) {
        csvContent = csvContent.replaceAll('(?<=")(.*?)(?=" <mailto)', '$1');
        String uploaderEmail = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Email;
        
        processCSV(csvContent, accountId, uploaderEmail);
    }
    
    private static void processCSV(String csvContent, Id accountId, String uploaderEmail) {
        List<String> errorMessages = new List<String>();
        List<CampaignMember> newCampaignMembers = new List<CampaignMember>();
        String[] lines = csvContent.split('\n');
        
        for (Integer i = 1; i < lines.size(); i++) { // Skip the header row
            String line = lines[i];
            String[] fields = line.split(',');
            if (fields.size() != 5) {
                errorMessages.add('Skipping invalid line ' + (i + 1) + ': ' + line);
                continue;
            }
            
            String firstName = fields[0].trim();
            String lastName = fields[1].trim();
            String trainingDateString = fields[2].trim();
            String trainingName = fields[3].trim();
            String email = fields[4].trim();
            
            if (!isValidEmail(email)) {
                errorMessages.add('Invalid email format at line ' + (i + 1) + ': ' + email);
                continue;
            }
            
            Date trainingDate;
            try {
                trainingDate = parseDate(trainingDateString);
            } catch (IllegalArgumentException e) {
                errorMessages.add('Invalid date format at line ' + (i + 1) + ': ' + trainingDateString + '. Please provide the date in DD-MM-YYYY or MM-DD-YYYY format.');
                continue;
            }
            
            List<Contact> existingContacts = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
            List<Lead> existingLeads = [SELECT Id FROM Lead WHERE Email = :email LIMIT 1];
            
            if (!existingContacts.isEmpty() || !existingLeads.isEmpty()) {
                // If it's a contact, create a CampaignMember for it
                if (!existingContacts.isEmpty()) {
                    Id contactId = existingContacts[0].Id;
                    Id campaignId = getCampaignId(trainingName.trim());
                    if (campaignId != null) {
                        CampaignMember cm = new CampaignMember(
                            ContactId = contactId,
                            CampaignId = campaignId
                        );
                        newCampaignMembers.add(cm);
                    } else {
                        errorMessages.add('No campaign found for training name: ' + trainingName + '. Contact: ' + email);
                    }
                }
                // If it's a lead, create a CampaignMember for it
                if (!existingLeads.isEmpty()) {
                    Id leadId = existingLeads[0].Id;
                    Id campaignId = getCampaignId(trainingName.trim());
                    if (campaignId != null) {
                        CampaignMember cm = new CampaignMember(
                            LeadId = leadId,
                            CampaignId = campaignId
                        );
                        newCampaignMembers.add(cm);
                    } else {
                        errorMessages.add('No campaign found for training name: ' + trainingName + '. Lead: ' + email);
                    }
                }
            } else {
                // Create new contact...
                try {
                    Contact newContact = new Contact(
                        FirstName = firstName,
                        LastName = lastName,
                        Email = email,
                        Training_Date__c = trainingDate,
                        Training_Name__c = trainingName,
                        AccountId = accountId
                    );
                    Database.SaveResult contactResult = Database.insert(newContact, false);
                    if (!contactResult.isSuccess()) {
                        for (Database.Error error : contactResult.getErrors()) {
                            errorMessages.add('Error creating contact at line ' + (i + 1) + ': ' + error.getMessage());
                        }
                    } else {
                        Id newCampaignId = getCampaignId(trainingName.trim());
                        if (newCampaignId != null) {
                            CampaignMember cm = new CampaignMember(
                                ContactId = newContact.Id,
                                CampaignId = newCampaignId
                            );
                            newCampaignMembers.add(cm);
                        } else {
                            errorMessages.add('No campaign found for training name: ' + trainingName + '. Contact: ' + email);
                        }
                    }
                } catch (Exception e) {
                    errorMessages.add('Exception creating contact at line ' + (i + 1) + ': ' + e.getMessage());
                }
            }
        }
        
        if (!newCampaignMembers.isEmpty()) {
            Database.SaveResult[] campaignMemberResults = Database.insert(newCampaignMembers, false);
            for (Integer j = 0; j < campaignMemberResults.size(); j++) {
                if (!campaignMemberResults[j].isSuccess()) {
                    for (Database.Error error : campaignMemberResults[j].getErrors()) {
                        errorMessages.add('Error creating campaign member: ' + error.getMessage());
                    }
                }
            }
        }
        
        if (!errorMessages.isEmpty()) {
            sendErrorEmail(uploaderEmail, errorMessages);
        }
    }
    
    private static Boolean isValidEmail(String email) {
        String emailRegex = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$';
        Pattern pattern = Pattern.compile(emailRegex);
        Matcher matcher = pattern.matcher(email);
        return matcher.matches();
    }
    
    private static Date parseDate(String dateString) {
        try {
            return Date.valueOf(dateString);
        } catch (Exception e1) {
            List<String> parts = dateString.split('-');
            if (parts.size() != 3) throw new IllegalArgumentException('Invalid date format.');
            
            Integer day = Integer.valueOf(parts[0]);
            Integer month = Integer.valueOf(parts[1]);
            Integer year = Integer.valueOf(parts[2]);
            
            if (year < 1000 || year > 9999 || month < 1 || month > 12 || day < 1 || day > 31) {
                throw new IllegalArgumentException('Invalid date value.');
            }
            
            return Date.newInstance(year, month, day);
        }
    }
    
    private static Id getCampaignId(String campaignName) {
        Campaign[] campaigns = [SELECT Id FROM Campaign WHERE Name = :campaignName LIMIT 1];
        return (campaigns.isEmpty()) ? null : campaigns[0].Id;
    }
    
    private static void sendErrorEmail(String toAddress, List<String> errorMessages) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { toAddress });
        mail.setSubject('CSV Upload Errors');
        mail.setPlainTextBody('The following errors occurred during CSV upload:\n\n' + String.join(errorMessages, '\n'));
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}