public with sharing class CampaignHelper {
    public static Id getCampaignId(String trainingName) {
        List<Campaign> campaigns = [SELECT Id FROM Campaign WHERE Name = :trainingName LIMIT 1];
        if (!campaigns.isEmpty()) {
            return campaigns[0].Id;
        } else {
            return null;
        }
    }
}