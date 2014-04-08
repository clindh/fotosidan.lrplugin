--[[----------------------------------------------------------------------------

FotosidanUser.lua
Fotosidan user account management

--------------------------------------------------------------------------------

Built on the Lightroom SDK sample plugin for Flickr:
ADOBE SYSTEMS INCORPORATED
 Copyright 2007-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

	-- Lightroom SDK
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrTasks = import 'LrTasks'

local logger = import 'LrLogger'( 'FotosidanPlugin' )
logger:enable("logfile")

require 'FotosidanAPI'


--============================================================================--

FotosidanUser = {}

--------------------------------------------------------------------------------

local function storedCredentialsAreValid( propertyTable )

	return propertyTable.username and string.len( propertyTable.username ) > 0
			and propertyTable.nsid 
			and propertyTable.auth_token

end

--------------------------------------------------------------------------------

local function notLoggedIn( propertyTable )

	propertyTable.token = nil
	
	propertyTable.nsid = nil
	propertyTable.username = nil
	propertyTable.fullname = ''
	propertyTable.auth_token = nil
	propertyTable.usertype = nil

	propertyTable.accountStatus = LOC "$$$/Fotosidan/AccountStatus/NotLoggedIn=Ej inloggad"
	propertyTable.loginButtonTitle = LOC "$$$/Fotosidan/LoginButton/NotLoggedIn=Logga in"
	propertyTable.loginButtonEnabled = true
	propertyTable.validAccount = false

end

--------------------------------------------------------------------------------

local doingLogin = false

function FotosidanUser.login( propertyTable )

	if doingLogin then return end
	doingLogin = true

	LrFunctionContext.postAsyncTaskWithContext( 'Fotosidan inloggning',
	function( context )

		-- Clear any existing login info, but only if creating new account.
		-- If we're here on an existing connection, that's because the login
		-- token was rejected. We need to retain existing account info so we
		-- can cross-check it.

		if not propertyTable.LR_editingExistingPublishConnection then
			notLoggedIn( propertyTable )
		end

		propertyTable.accountStatus = LOC "$$$/Fotosidan/AccountStatus/LoggingIn=Loggar in..."
		propertyTable.loginButtonEnabled = false
		
		LrDialogs.attachErrorDialogToFunctionContext( context )
		
		-- Make sure login is valid when done, or is marked as invalid.
		
		context:addCleanupHandler( function()

			doingLogin = false

			if not storedCredentialsAreValid( propertyTable ) then
				notLoggedIn( propertyTable )
			end
			
			-- Hrm. New API doesn't make it easy to show what operation failed.
			-- LrDialogs.message( LOC "$$$/Fotosidan/LoginFailed=Failed to log in." )

		end )
		
		-- Make sure we have an API key.
		
		FotosidanAPI.getApiKeyAndSecret()

		-- Show request for authentication dialog.
	
		local authRequestDialogResult = LrDialogs.confirm(
			LOC "$$$/Fotosidan/AuthRequestDialog/Message=Lightroom behöver din tillåtelse för att kunna ladda upp på Fotosidan.",
			LOC "$$$/Fotosidan/AuthRequestDialog/HelpText=När du klickar Godkänn så öppnas webbläsaren, och du kan logga in på Fotosidan och godkänna Lightroom. Återvänd sedan till detta fönster för att fortsätta.",
			LOC "$$$/Fotosidan/AuthRequestDialog/AuthButtonText=Godkänn",
			LOC "$$$/LrDialogs/Cancel=Avbryt" )
	
		if authRequestDialogResult == 'cancel' then
			return
		end
	
		-- Request the frob that we need for authentication.
		
		propertyTable.accountStatus = LOC "$$$/Fotosidan/AccountStatus/WaitingForFotosidan=Väntar på svar från fotosidan.se..."

		require 'FotosidanAPI'
		local frob = FotosidanAPI.openAuthUrl()
	
		local waitForAuthDialogResult = LrDialogs.confirm(
			LOC "$$$/Fotosidan/WaitForAuthDialog/Message=Återvänd till detta fönster när du godkänt att Lightroom får komma år dina bilder.",
			LOC "$$$/Fotosidan/WaitForAuthDialog/HelpText=När du godkänt Lightroom på fotosidan.se (i din webbläsare), klicka på Klar nedan.",
			LOC "$$$/Fotosidan/WaitForAuthDialog/DoneButtonText=Klar",
			LOC "$$$/LrDialogs/Cancel=Cancel" )
	
		if waitForAuthDialogResult == 'cancel' then
			return
		end
	
		-- User has OK'd authentication. Get the user info.
		
		propertyTable.accountStatus = LOC "$$$/Fotosidan/AccountStatus/WaitingForFotosidan=Väntar på svar från fotosidan.se..."

		local data = FotosidanAPI.callRestMethod( propertyTable, { method = 'flickr.auth.getToken', frob = frob, suppressError = true, skipAuthToken = true } )
		
		local auth = data.auth
		
		if not auth then
			return
		end
		
		-- If editing existing connection, make sure user didn't try to change user ID on us.
		
		if propertyTable.LR_editingExistingPublishConnection then
		
			if auth.user and propertyTable.nsid ~= auth.user.nsid then
				LrDialogs.message( LOC "$$$/Fotosidan/CantChangeUserID=Du kan inte byta Fotosidan-inloggning på en befintlig publiceringskoppling. Logga in som den medlem som skapade denna koppling." )
				return
			end
		
		end
		
		-- Now we can read the Fotosidan user credentials. Save off to prefs.
	
		propertyTable.nsid = auth.user.nsid
		propertyTable.username = auth.user.username
		propertyTable.fullname = auth.user.fullname
		propertyTable.usertype = auth.user.type
		propertyTable.auth_token = auth.token._value
		
		FotosidanUser.updateUserStatusTextBindings( propertyTable )
		
	end )

end

--------------------------------------------------------------------------------

local function getDisplayUserNameFromProperties( propertyTable )

	local displayUserName = propertyTable.fullname
	if ( not displayUserName or #displayUserName == 0 )
		or displayUserName == propertyTable.username
	then
		displayUserName = propertyTable.username
	else
		displayUserName = LOC( "$$$/Fotosidan/AccountStatus/UserNameAndLoginName=^1 (^2)",
							propertyTable.fullname,
							propertyTable.username
							)
	end
	
	return displayUserName

end

--------------------------------------------------------------------------------

function FotosidanUser.verifyLogin( propertyTable )

	-- Observe changes to prefs and update status message accordingly.

	local function updateStatus()
	
		logger:trace( "verifyLogin: updateStatus() was triggered." )
		
		LrTasks.startAsyncTask( function()
			logger:trace( "verifyLogin: updateStatus() is executing." )
			if storedCredentialsAreValid( propertyTable ) then
			     
				local displayUserName = getDisplayUserNameFromProperties( propertyTable )
				
				propertyTable.accountStatus = LOC( "$$$/Fotosidan/AccountStatus/LoggedIn=Inloggad som ^1", displayUserName )
			
				if propertyTable.LR_editingExistingPublishConnection then
					propertyTable.loginButtonTitle = LOC "$$$/Fotosidan/LoginButton/LogInAgain=Logga in"
					propertyTable.loginButtonEnabled = false
					propertyTable.validAccount = true
				else
					propertyTable.loginButtonTitle = LOC "$$$/Fotosidan/LoginButton/LoggedIn=Byt inloggning"
					propertyTable.loginButtonEnabled = true
					propertyTable.validAccount = true
				end
			else
				notLoggedIn( propertyTable )
			end
	
			FotosidanUser.updateUserStatusTextBindings( propertyTable )
		end )
		
	end

	propertyTable:addObserver( 'auth_token', updateStatus )
	updateStatus()
	
end

--------------------------------------------------------------------------------

function FotosidanUser.updateUserStatusTextBindings( settings )

	local nsid = settings.nsid
	
	if nsid and string.len( nsid ) > 0 then

		LrFunctionContext.postAsyncTaskWithContext( 'Fotosidan inloggningskontroll',
		function( context )
		
			context:addFailureHandler( function()

				-- Login attempt failed. Offer chance to re-establish connection.

				if settings.LR_editingExistingPublishConnection then
				
					local displayUserName = getDisplayUserNameFromProperties( settings )
					
					settings.accountStatus = LOC( "$$$/Fotosidan/AccountStatus/LogInFailed=Inloggning misslyckades, var inloggad som ^1", displayUserName )

					settings.loginButtonTitle = LOC "$$$/Fotosidan/LoginButton/LogInAgain=Logga in"
					settings.loginButtonEnabled = true
					settings.validAccount = false
					
					settings.isUserPro = false
					settings.accountTypeMessage = LOC "$$$/Fotosidan/AccountStatus/LoginFailed/Message=Kunde ej verifiera Fotosidan-inloggningen. Pröva att logga in igen. OBS att du inte kan byta till annan medlem på en existerande publiceringskoppling, du måste logga in med samma medlemskap."

				end
			
			end )
		
			local userinfo = FotosidanAPI.getUserInfo( settings, { userId = nsid } )
			if userinfo and ( not userinfo.ispro ) then
				settings.accountTypeMessage = LOC( "$$$/Fotosidan/NonProAccountLimitations=Detta är inte ett plusmedlemskap, begränsningar kan förekomma." )
				settings.isUserPro = false
			else
				settings.accountTypeMessage = LOC( "$$$/Fotosidan/ProAccountDescription=Detta är ett plusmedlemskap." )
				settings.isUserPro = true
			end
			
		end )
	else

		settings.accountTypeMessage = LOC( "$$$/Fotosidan/SignIn=Logga in på Fotosidan." )
		settings.isUserPro = false

	end

end
