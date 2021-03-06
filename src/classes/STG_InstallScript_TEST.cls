/*
    Copyright (c) 2014, Salesforce.org
    All rights reserved.
    
    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2014
* @group Settings
* @group-content ../../ApexDocContent/Settings.htm
* @description Test Class for the Install Script for the HEDA package. 
*/
@isTest
public with sharing class STG_InstallScript_TEST {

	@isTest
	public static void onInstall() {
        Contact cont = new Contact(
            FirstName = 'Joe',
            LastName = 'Test',
            Email = 'joe@domain.com'
        );
        CON_Preferred_TDTM.alreadyRunBefore = true; // need to turn off the trigger for this test
        insert cont;

        CON_Preferred_TDTM.alreadyRunBefore = false; // back on for install script

        Test.startTest();
		//Run the install script
        Test.testInstall(new STG_InstallScript(), null);
        Test.stopTest();

        List<Affl_Mappings__c> mappings = [select Account_Record_Type__c, Primary_Affl_Field__c from Affl_Mappings__c];
        System.assertEquals(6, mappings.size());
        List<Trigger_Handler__c> tdtmHandlers = [select Name from Trigger_Handler__c];
        System.assertEquals(TDTM_DefaultConfig.getDefaultRecords().size(), tdtmHandlers.size());

        // Making sure the Batch process ran successfully
        Contact cont2 = [SELECT Id, Name, Email, AlternateEmail__c, Preferred_Email__c FROM Contact WHERE Id =: cont.Id];
        System.assertEquals(cont2.AlternateEmail__c, cont2.Email);

	}
	
	//If the handlers in our default TDTM config are different from what it's in the org (either action or load order),
    //and the user did not flag them as user managed, we need to update them
    @isTest
    public static void handlersChanged() {
    	//Handlers that exist in the org
        List<TDTM_Global_API.TdtmToken> oldHandlers = new List<TDTM_Global_API.TdtmToken>();
        oldHandlers.add(new TDTM_Global_API.TdtmToken('AFFL_Affiliations_TDTM', 'Contact', 'AfterInsert', 1));
        oldHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Cm_TDTM', 'CampaignMember', 'AfterInsert;AfterUpdate', 1));
        oldHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Con_TDTM', 'Contact', 'AfterInsert;AfterDelete', 1));
    	TDTM_Global_API.setTdtmConfig(oldHandlers);
    	
    	//Updated handlers
    	List<TDTM_Global_API.TdtmToken> updatedHandlers = new List<TDTM_Global_API.TdtmToken>();
    	updatedHandlers.add(new TDTM_Global_API.TdtmToken('AFFL_Affiliations_TDTM', 'Contact', 'AfterInsert;AfterUpdate', 1));
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Cm_TDTM', 'CampaignMember', 'AfterInsert;AfterUpdate', 0));
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Con_TDTM', 'Contact', 'AfterInsert;AfterUpdate;AfterDelete', 2));
    	
    	Test.startTest();
    	STG_InstallScript.updateDefaultTdtmConfig(updatedHandlers);
    	Test.stopTest();
    	
    	//Verify handlers have been updated
    	List<Trigger_Handler__c> newHandlers = [select Load_Order__c, Class__c, Trigger_Action__c from Trigger_Handler__c order by Load_Order__c];
        
        System.assertEquals(0, newHandlers[0].Load_Order__c);   
        System.assertEquals('REL_Relationships_Cm_TDTM', newHandlers[0].Class__c);   
        System.assertEquals('AfterInsert;AfterUpdate', newHandlers[0].Trigger_Action__c);
        
        System.assertEquals(1, newHandlers[1].Load_Order__c);   
        System.assertEquals('AFFL_Affiliations_TDTM', newHandlers[1].Class__c);   
        System.assertEquals('AfterInsert;AfterUpdate', newHandlers[1].Trigger_Action__c);  
        
        System.assertEquals(2, newHandlers[2].Load_Order__c);   
        System.assertEquals('REL_Relationships_Con_TDTM', newHandlers[2].Class__c);   
        System.assertEquals('AfterInsert;AfterUpdate;AfterDelete', newHandlers[2].Trigger_Action__c);    
    }
    
    //If the handlers in our default TDTM config are different from what it's in the org (either action or load order),
    //and the user flagged them as user managed, we do not need to update them
    // also test that new handlers are added 
    @isTest
    public static void handlersChanged_UserManaged() {
        
        //Handlers that exist in the org
        List<TDTM_Global_API.TdtmToken> oldHandlers = new List<TDTM_Global_API.TdtmToken>();
        //Should not be modified
        TDTM_Global_API.TdtmToken token1 = new TDTM_Global_API.TdtmToken('AFFL_Affiliations_TDTM', 'Contact', 'AfterInsert', 1);
        token1.userManaged = true;
        oldHandlers.add(token1);
        
        //Should be modified
        oldHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Cm_TDTM', 'CampaignMember', 'AfterInsert;AfterUpdate', 1));
        
        //Should not be modified
        TDTM_Global_API.TdtmToken token3 = new TDTM_Global_API.TdtmToken('REL_Relationships_Con_TDTM', 'Contact', 'AfterInsert;AfterDelete', 2);
        token3.userManaged = true;
        oldHandlers.add(token3);

        TDTM_Global_API.setTdtmConfig(oldHandlers);

        // Create fourth trigger handler to simulate a new record added by a user.
        Trigger_Handler__c custTrigHand = new Trigger_Handler__c(
            Active__c = true, 
            Asynchronous__c = false, 
            Class__c = 'ADDR_Addresses_TDTM', 
            Load_Order__c = 1, 
            Object__c = 'Address__c', 
            Trigger_Action__c = 'BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate;AfterDelete',
            User_Managed__c = true
        );
        insert custTrigHand; // Must be inserted after setTdtmConfig() to prevent deletion
        
        //Updated handlers
        List<TDTM_Global_API.TdtmToken> updatedHandlers = new List<TDTM_Global_API.TdtmToken>();
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('AFFL_Affiliations_TDTM', 'Contact', 'AfterInsert;AfterUpdate', 1));
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Cm_TDTM', 'CampaignMember', 'AfterInsert;AfterUpdate', 0));
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('REL_Relationships_Con_TDTM', 'Contact', 'AfterInsert;AfterUpdate;AfterDelete', 1));
        
        // Add new items added to default
        updatedHandlers.add(new TDTM_Global_API.TdtmToken('ADDR_Contact_TDTM', 'Contact', 'BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate', 2));

        Test.startTest();
        STG_InstallScript.updateDefaultTdtmConfig(updatedHandlers);
        Test.stopTest();
        
        //Verify handlers marked as "User Managed" were not modified
        List<Trigger_Handler__c> newHandlers = [select Load_Order__c, Class__c, Trigger_Action__c from Trigger_Handler__c order by Load_Order__c];

        // Make sure the manually added items are not deleted.
        System.assertEquals(5, newHandlers.size());   
        
        // Individually check each handler scenario
        for (Trigger_Handler__c handler : newHandlers) {
            if(handler.Class__c == 'REL_Relationships_Cm_TDTM') {
                 //Should have been modified
                System.assertEquals(0, handler.Load_Order__c); 
                System.assertEquals('AfterInsert;AfterUpdate', handler.Trigger_Action__c);
            } else if (handler.Class__c == 'AFFL_Affiliations_TDTM') {
                //Should not have been modified 
                System.assertEquals(1, handler.Load_Order__c);
                System.assertEquals('AfterInsert', handler.Trigger_Action__c); 
            } else if (handler.Class__c == 'REL_Relationships_Con_TDTM') {
                //Should not have been modified
                System.assertEquals(2, handler.Load_Order__c);
                System.assertEquals('AfterInsert;AfterDelete', handler.Trigger_Action__c);
            } else if (handler.Class__c == 'ADDR_Addresses_TDTM') {
                //Should not have been modified
                System.assertEquals(1, handler.Load_Order__c);
                System.assertEquals('BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate;AfterDelete', handler.Trigger_Action__c);  
            } else if (handler.Class__c == 'ADDR_Contact_TDTM') {
                //Should have been added
                System.assertEquals(2, handler.Load_Order__c);
                System.assertEquals('BeforeInsert;BeforeUpdate;AfterInsert;AfterUpdate', handler.Trigger_Action__c);  
            }
        }
    }
    
    @isTest
    public static void changeAdminAccAddressParent() {
        //Create 201 accounts of adminRecType
        String adminRecTypeId = UTIL_Describe.getAdminAccRecTypeID();
        List<Account> accs = new List<Account>();
        for(Integer i = 0; i < 200; i++) {
            accs.add(new Account(Name = 'acctest' + i, RecordTypeId = adminRecTypeId));
        }
        insert accs;
        
        //Create 201 contacts and link them with those accounts
        List<Contact> contacts = new List<Contact>();
        for(Integer i = 0; i < 200; i++) {
            contacts.add(new Contact(LastName = 'contest' + i, AccountId = accs[i].Id));
        }
        insert contacts;
        
        //Create 201 addresses and link them with those accounts
        List<Address__c> addrs = new List<Address__c>();
        for(Integer i = 0; i < 200; i++) {
            addrs.add(new Address__c(Parent_Account__c = accs[i].Id));
        }
        insert addrs;
        
        //Run script
        Test.startTest();      
        STG_InstallScript.reparentAdminAddrs(new Version(1, 14));
        Test.stopTest();
        
        //Verify addresses are now linked with the contacts
        addrs = [select Parent_Account__c, Parent_Contact__c from Address__c where ID IN :addrs];
        for(Address__c addr : addrs) {
            System.assertEquals(null, addr.Parent_Account__c);
            System.assertNotEquals(null, addr.Parent_Contact__c);   
        }
    }
}