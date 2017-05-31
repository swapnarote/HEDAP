@isTest
private class NOMERGE_Trigger_Handler_Management {

	@testSetup static void insertData() {
		// Crate handlers to act as defaults
		List<Trigger_Handler__c> handlers = TDTM_DefaultConfig.getDefaultRecords();
		insert handlers;
	}

	/***
		Test the refactored token equals and hashCode
	***/
	@isTest
	public static void verifyEquality() { 
		List<Trigger_Handler__c> defaults = TDTM_DefaultConfig.getDefaultRecords();
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> defaultsMapTokens = gimmeTokens(defaults);

        List<Trigger_Handler__c> existingDBHandlers = [SELECT Active__c , Asynchronous__c , Class__c , Load_Order__c , Object__c , Trigger_Action__c
	        , User_Managed__c, Owned_by_Namespace__c
			FROM Trigger_Handler__c ORDER BY Load_Order__c];

        // Handlers from Database should match the defaults from Config.
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> existingDBtokens = gimmeTokens(existingDBHandlers);

		System.assertEquals(defaultsMapTokens.hashCode(), existingDBtokens.hashCode() );
		//System.assertEquals(defaultsMapTokens, existingDBtokens );
	}

	/***
		Test the Old Method of trigger Management just to run through to test timing.
	***/
	@isTest
	public static void handlersOGMethod() {
		List<Trigger_Handler__c> messyDefaults = messWithDefaults();
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> newDefaults = gimmeTokens(messyDefaults);

		System.debug('********** handlersOGMethod START: ' + System.now() + ' : ' + System.currentTimeMillis() );
		
		STG_InstallScript.updateDefaultTdtmConfig(new List<TDTM_Global_API.TdtmToken>(newDefaults.keySet()) );

		System.debug('********** handlersOGMethod END: ' + System.now() + ' : ' + System.currentTimeMillis() );
	}

	/***
		Proof of concept method for changes to Trigger handler Management. This makes use of a new Owned_by_Namespace__c field to keep hands off other package Trigger Handlers.
	***/	
	@isTest
	public static void handlersNewMethod() {
		
		// Setup Defaults
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> newTokens = gimmeTokens (messWithDefaults() );

		System.debug('********** handlersNewMethod START: ' + System.now() + ' : ' + System.currentTimeMillis() );
	
		// Get current values from database that we own
		Map<Id,Trigger_Handler__c> existingHandlers = new Map<Id,Trigger_Handler__c>([SELECT Id, Active__c,  Asynchronous__c,  Object__c,  Load_Order__c,  Class__c,  Trigger_Action__c,  User_Managed__c, Owned_by_Namespace__c FROM Trigger_Handler__c WHERE Owned_by_Namespace__c =: UTIL_Namespace.getNamespace() ORDER BY Load_Order__c ]);

        List<Trigger_Handler__c> toDelete = new List<Trigger_Handler__c>();
        List<Trigger_Handler__c> toUpsert = new List<Trigger_Handler__c>();

		// Setup Tokens for existing records from database        
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> existingTokens = gimmeTokens(existingHandlers.values() );
        
		// Check for changes
		if(newTokens != existingTokens) {
			
			for( TDTM_Global_API.TdtmToken existingToken : existingTokens.keySet() ){
			
				existingTokens.remove(existingToken);  // mark processed
				newTokens.remove(existingToken); // mark processed

				// Skip usermanaged and unchanged items
				if( !existingToken.userManaged && newTokens.containsKey(existingToken) ) {
					
					//Check if updated or deleted altogether from default
					TDTM_Global_API.TdtmToken match = existingToken.getmatch( newTokens.keySet() );
					if(match != null) {
						// Update current handler value
						toUpsert.add( mergeToken(existingHandlers.get(existingToken.handlerId),match ) );
					
					// Must have been deleted 
					} else {
						// Remove from existing list and setup for deletion
						toDelete.add(existingHandlers.remove(existingToken.handlerId));
					}
				}
			}
			
			// Check for new items to add since these didn't match against existing items
			if(newTokens.size() > 0) {
				for(TDTM_Global_API.TdtmToken newToken: newTokens.values()){
					toUpsert.add( mergeToken(new Trigger_Handler__c() ,newToken ) );
				}
			}
		}
		
		upsert toUpsert;
		delete toDelete;

		System.debug('********** handlersNewMethod END: ' + System.now() + ' : ' + System.currentTimeMillis() );

		// GO back to the database to verify it all worked as expexted
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> existingDBtokens = gimmeTokens([SELECT Class__c, Object__c, Trigger_Action__c, Load_Order__c, Active__c, Asynchronous__c, User_Managed__c, Owned_by_Namespace__c FROM Trigger_Handler__c ORDER BY Load_Order__c]);

		System.assertEquals(newTokens.hashCode(), existingDBtokens.hashCode() );
	}

	/***
		// Create an Identity Map of the TDTM Tokens for later processing
	***/
	private static Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> gimmeTokens(List<Trigger_Handler__c> hs) {
        
        Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken> ts = new Map<TDTM_Global_API.TdtmToken,TDTM_Global_API.TdtmToken>();

		for(Trigger_Handler__c h: hs) {
			TDTM_Global_API.TdtmToken newToken = new TDTM_Global_API.TdtmToken(
				h.Class__c, // className
				h.Object__c, // targetObject
				h.Trigger_Action__c, // actions
				Integer.valueOf(h.Load_Order__c), // loadOrder
				h.Active__c, // active
				h.Asynchronous__c, // async
				h.User_Managed__c, // user managed
				h.Owned_by_Namespace__c // namespace
			);
		
			// Conditionally set Id 
			if(h.Id != null) {
				newToken.handlerId = h.Id;
			}
			ts.put(newToken,newToken );
		}

		return ts;
	}

	/***
		Merge token data into Trigger Handler. Has a special case to check if the token does not contain an ID. If not, it is a new handler so it adds classname and target object to the handler definition.
	***/
	private static Trigger_Handler__c mergeToken(Trigger_Handler__c h, TDTM_Global_API.TdtmToken alien) {
        h.Trigger_Action__c = alien.actions;
        h.Active__c = alien.active;
        h.Load_Order__c = alien.loadOrder;
        h.Asynchronous__c = alien.async;
        h.User_Managed__c = alien.userManaged;
        h.Owned_by_Namespace__c = alien.ownedByNamespace;

        if(alien.handlerId == null) {
			h.Class__c = alien.className;  
			h.Object__c = alien.targetObject;
        }
        return h;
	}

	/***
		Loop through defaults and make changes to simulate new defaults. If we maintain something like this for production unit test, we'll want to explicitly test for New handlers added to defaults as well as Removing Handlers.
	***/
	private static List<Trigger_Handler__c> messWithDefaults() {
		List<Trigger_Handler__c> handlers = TDTM_DefaultConfig.getDefaultRecords();

		Integer newOrder = 10;
		for(Trigger_Handler__c t: handlers) {
			t.Load_Order__c = newOrder;
			newOrder = newOrder+1;
		}
		return handlers;
	}
}