--[[----------------------------------------------------------------------------

FotosidanExportServiceProvider.lua
Export service provider description for Lightroom Fotosidan uploader

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

local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrBinding = import 'LrBinding'
local LrDialogs = import 'LrDialogs'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrApplication = import 'LrApplication'
local LrFunctionContext = import 'LrFunctionContext'

	-- Common shortcuts
local bind = LrView.bind
local share = LrView.share

	-- Fotosidan plug-in
require 'FotosidanAPI'
require 'FotosidanPublishSupport'
Info = require 'Info'

local logger = import 'LrLogger'( 'FotosidanPlugin' )
logger:enable("logfile")

local Debug

-- local Require = require 'Require'.path ("../debugscript.lrdevplugin")
-- require 'strict'
-- Debug = require 'Debug'.init ()

--============================================================================--

local exportServiceProvider = {}

-- A typical service provider would probably roll all of this into one file, but
-- this approach allows us to document the publish-specific hooks separately.

for name, value in pairs( FotosidanPublishSupport ) do
	exportServiceProvider[ name ] = value
end

exportServiceProvider.supportsIncrementalPublish = 'true'

exportServiceProvider.exportPresetFields = {
	{ key = 'username', default = "" },
	{ key = 'fullname', default = "" },
	{ key = 'usertype', default = "" },
	{ key = 'nsid', default = "" },
	{ key = 'isUserPro', default = false },
	{ key = 'auth_token', default = '' },
	{ key = 'type', default = 'photo' },
	{ key = 'addToPhotoset', default = false },
	{ key = 'photoset', default = '' },
	{ key = 'titleFirstChoice', default = 'title' },
	{ key = 'titleSecondChoice', default = 'filename' },
	{ key = 'titleRepublishBehavior', default = 'replace' },
	{ key = 'albumId', default = '' },
	{ key = 'saveHistory', default = false },
	{ key = 'doNotDeleteOnFS', default = false },
	{ key = 'syncComments', default = false },
}


exportServiceProvider.hideSections = { 'exportLocation', 'video' }
-- exportServiceProvider.canExportToTemporaryLocation = true -- this is the default when section is hidden 

exportServiceProvider.allowFileFormats = { 'JPEG', 'GIF' }

exportServiceProvider.allowColorSpaces = { 'sRGB', 'AdobeRGB' }
	
exportServiceProvider.hidePrintResolution = true

exportServiceProvider.canExportVideo = false      -- video is not supported 

--------------------------------------------------------------------------------
-- FOTOSIDAN SPECIFIC: Helper functions and tables.

local function updateCantExportBecause( propertyTable )

	if not propertyTable.validAccount then
		propertyTable.LR_cantExportBecause = LOC "$$$/Fotosidan/ExportDialog/NoLogin=Du har inte loggat in på Fotosidan än."
		return
	end
	
	propertyTable.LR_cantExportBecause = nil

end

local displayNameForTitleChoice = {
	title = LOC "$$$/Fotosidan/ExportDialog/Title/Title=Bildens rubrik i Lightroom",
	filename = LOC "$$$/Fotosidan/ExportDialog/Title/Filename=Bildfilens namn",
	empty = LOC "$$$/Fotosidan/ExportDialog/Title/Empty=Bildens Fotosidan-ID",
}


local function booleanToNumber( value )
	return value and 1 or 0
end

local function getFotosidanTitle( photo, exportSettings, pathOrMessage )

	local title
			
	-- Get title according to the options in Fotosidan Title section.

	if exportSettings.titleFirstChoice == 'filename' then
				
		title = LrPathUtils.leafName( pathOrMessage )
				
	elseif exportSettings.titleFirstChoice == 'title' then
				
		title = photo:getFormattedMetadata 'title'
				
		if ( not title or #title == 0 ) and exportSettings.titleSecondChoice == 'filename' then
			title = LrPathUtils.leafName( pathOrMessage )
		end

	end
				
	return title

end

function exportServiceProvider.startDialog( propertyTable )

        propertyTable.LR_size_doConstrain = true
        propertyTable.LR_size_doNotEnlarge = true 

        if propertyTable.LR_jpeg_quality < 0.7 then
	   propertyTable.LR_jpeg_quality = 0.8
	end

        if propertyTable.LR_size_maxHeight == 1000 then
	   propertyTable.LR_size_maxHeight = 1920
	end

        if propertyTable.LR_size_maxWidth == 1000 then
	   propertyTable.LR_size_maxWidth = 2880
	end

	-- Clear login if it's a new connection.
	if not propertyTable.LR_editingExistingPublishConnection then
		propertyTable.username = nil
		propertyTable.nsid = nil
		propertyTable.auth_token = nil
	end

	-- Can't export until we've validated the login.

	propertyTable:addObserver( 'validAccount', function() updateCantExportBecause( propertyTable ) end )
	updateCantExportBecause( propertyTable )

	-- Make sure we're logged in.

	require 'FotosidanUser'
	FotosidanUser.verifyLogin( propertyTable )

end

function exportServiceProvider.sectionsForTopOfDialog( f, propertyTable )

   local def = {}

   local userinfo

   -- Login section 
   --
   def[#def+1] = {
      title = LOC "$$$/Fotosidan/ExportDialog/Account=Fotosidan: Inloggning   (v" .. Info.VERSION.major .. "." .. Info.VERSION.minor .. ")",
      synopsis = bind 'accountStatus',

      f:row {
	 spacing = f:control_spacing(),
	 
	 f:static_text {
	    title = bind 'accountStatus',
	    alignment = 'right',
	    fill_horizontal = 1, 
         },

	 f:push_button {
	    width = tonumber( LOC "$$$/locale_metric/Fotosidan/ExportDialog/LoginButton/Width=100" ),
	    title = bind 'loginButtonTitle',
	    enabled = bind 'loginButtonEnabled',
	    action = function()
	       require 'FotosidanUser'
	       FotosidanUser.login( propertyTable )
	    end,
         },
      },
   }
	
   -- Settings section 
   --
   def[#def+1] = {
      title = LOC "$$$/Fotosidan/ExportDialog/Title=Fotosidan: Inställningar",
			
      synopsis = function( props )
	 if props.titleFirstChoice == 'title' then
	    return LOC( "$$$/Fotosidan/ExportDialog/Synopsis/TitleWithFallback=IPTC Title or ^1",
	                displayNameForTitleChoice[ props.titleSecondChoice ] )
	 else
	    return props.titleFirstChoice and displayNameForTitleChoice[ props.titleFirstChoice ] or ''
	 end
      end,
			
      f:column {
	 spacing = f:control_spacing(),

	 f:row {
	    spacing = f:label_spacing(),
	    
	    f:static_text {
	       title = LOC "$$$/Fotosidan/ExportDialog/ChooseTitleBy=Använd som bildens rubrik:",
	       alignment = 'right',
	       width = share 'fsTitleSectionLabel',
  	    },
	    
	    f:popup_menu {
	       value = bind 'titleFirstChoice',
	       width = share 'fsTitleLeftPopup',
	       items = {
		  { value = 'title', title = displayNameForTitleChoice.title },
		  { value = 'empty', title = displayNameForTitleChoice.empty },
		  { value = 'filename', title = displayNameForTitleChoice.filename },
	       },
	    },

	    f:spacer { width = 20 },
	    
	    f:static_text {
	       title = LOC "$$$/Fotosidan/ExportDialog/ChooseTitleBySecondChoice=Om tomt, använd:",
	       enabled = LrBinding.keyEquals( 'titleFirstChoice', 'title', propertyTable ),
	    },
	    
	    f:popup_menu {
	       value = bind 'titleSecondChoice',
	       enabled = LrBinding.keyEquals( 'titleFirstChoice', 'title', propertyTable ),
	       items = {
		  { value = 'empty', title = displayNameForTitleChoice.empty },	
		  { value = 'filename', title = displayNameForTitleChoice.filename },
	       },
  	    },
	 },
	 
	 f:row {
	    spacing = f:label_spacing(),
	    
	    f:static_text {
	       title = LOC "$$$/Fotosidan/ExportDialog/OnUpdate=Vid ompublicering:",
	       alignment = 'right',
	       width = share 'fsTitleSectionLabel',
			  },
	    
	    f:popup_menu {
	       value = bind 'titleRepublishBehavior',
	       width = share 'fsTitleLeftPopup',
	       items = {
		  { value = 'replace', title = LOC "$$$/Fotosidan/ExportDialog/ReplaceExistingTitle=Ersätt rubriken" },
		  { value = 'leaveAsIs', title = LOC "$$$/Fotosidan/ExportDialog/LeaveAsIs=Rör ej rubriken" },
	       },
	    },
	 },	    

	 f:row {
	    spacing = f:label_spacing(),

 	    f:checkbox {
	    	value = bind 'saveHistory',
		title = "Spara tidigare version",
		enabled = bind 'isUserPro',
  	    },	

 	    f:checkbox {
	    	value = bind 'doNotDeleteOnFS',
		title = "Radera EJ bilder på Fotosidan",
		enabled = propertyTable.LR_isExportForPublish,
  	    },	
 	    f:checkbox {

	    	value = bind 'syncComments',
		title = "Synka kommentarer",
		enabled = propertyTable.LR_isExportForPublish,
  	    },	

	 },

 

	},

    }
   
   -- Album section 
   --
   if not propertyTable.LR_isExportForPublish then

      if not propertyTable.validAccount then
	 propertyTable.albumList = {{ value = '', title = '(logga in)'}} 
      end

      local function updateAlbumList(propertyTable, key, newValue)
	 if not newValue then
	    return
	 end

	 LrTasks.startAsyncTask( function()
				    local list = FotosidanAPI.getAlbums(propertyTable, true)			    
				    list[#list + 1] = { value="", title="(skapa nytt album)"}
				    propertyTable.albumList = list
				 end )
      end
      propertyTable:addObserver( 'validAccount', updateAlbumList )

      local albumDef = {
	 title = LOC "$$$/Fotosidan/ExportDialog/Account=Fotosidan: Album",
	 spacing = f:control_spacing(),
	 f:static_text {
	    title = "Välj i vilket av dina album på Fotosidan du vill lägga in bilderna i:",
		       },
      }

      local version = LrApplication:versionTable()

      -- simple_list is supported in LR4 and above
      --
      if version.major < 4 then
	 albumDef[#albumDef+1] = f:popup_menu {
	    items = bind 'albumList',
	    value = bind 'albumId',
	    width = 500,
	    immediate = true,
	 }
      else
	 albumDef[#albumDef+1] = f:simple_list {
	    items = bind 'albumList',
	    value = bind 'albumId',
	    width = 500,
	    immediate = true,
	 }
      end

      albumDef[#albumDef+1] = 
	 f:row {
	 f:static_text {
	    title = "Namn på nytt album",
		       },
	 
	 f:edit_field {
	    value = bind 'newAlbumName',
	    width = 400,
		      },
	       }
	 
       def[#def+1] = albumDef

   end

   return def;

end

function exportServiceProvider.sectionsForBottomOfDialog( f, propertyTable )
    return { }
end


function exportServiceProvider.processRenderedPhotos(functionContext, exportContext )
	

	local exportSession = exportContext.exportSession

	-- Make a local reference to the export parameters.
	
	local exportSettings = assert( exportContext.propertyTable )
		
	-- Get the # of photos.
	
	local nPhotos = exportSession:countRenditions()
	
	local publishedCollectionInfo = exportContext.publishedCollectionInfo

	-- Set progress title.
	
	local progressScope = exportContext:configureProgress {
				title = nPhotos > 1
				and LOC( "$$$/Fotosidan/Publish/Progress=Publicerar ^1 bilder på Fotosidan", nPhotos )
				or LOC "$$$/Fotosidan/Publish/Progress/One=Publicerar en bild på Fotosidan",
				}


	-- Save off uploaded photo IDs so we can take user to those photos later.
	
	local uploadedPhotoIds = {}
	local collectionSettings = {}	
	local isDefaultCollection = true

	local photosetPhotosSet = {}	
	local photosetPhotoIds = {}	

	local photosetId
	local photosetUrl

	if publishedCollectionInfo then

		local publishedCollection = exportContext.publishedCollection
		local collectionInfo = publishedCollection:getCollectionInfoSummary()
		local collectionSettings = collectionInfo.collectionSettings

		if not collectionSettings then
		   collectionSettings = { }
		end

		isDefaultCollection = publishedCollectionInfo.isDefaultCollection 

		-- Look for a photoset id for this collection.

		photosetId = publishedCollectionInfo.remoteId

		if not photosetId then
			photosetId, photosetUrl = FotosidanAPI.createOrUpdatePhotoset( exportSettings, {
							title = publishedCollectionInfo.name,
							type = collectionSettings.albumType,
							access = collectionSettings.albumAccess,
							} )
			collectionSettings.albumId = photosetId
		end

		-- Get a list of photos already in this photoset so we know which ones we can replace and which have
		-- to be re-uploaded entirely.

		photosetPhotoIds = photosetId and FotosidanAPI.listPhotosFromPhotoset( exportSettings, { photosetId = photosetId } )
	
		-- Turn it into a set for quicker access later.

		if photosetPhotoIds then
			for _, id in ipairs( photosetPhotoIds ) do	
				photosetPhotosSet[ id ] = true
			end
		end

	elseif exportSettings.newAlbumName then
		photosetId, photosetUrl = FotosidanAPI.createOrUpdatePhotoset( exportSettings, {
						title = exportSettings.newAlbumName,
						type = exportSettings.albumType,
						access = exportSettings.albumAccess,
						} )
	elseif exportSettings.albumId[1] then
		photosetId, photosetUrl = FotosidanAPI.createOrUpdatePhotoset( exportSettings, {
						photosetId = exportSettings.albumId[1],
						} )

	end	

	local fsPhotoIdsForRenditions = {}
	
	-- Gather fs photo IDs, and remember the renditions that
	-- had been previously published.

	for i, rendition in exportContext.exportSession:renditions() do
	
		local fsPhotoId = rendition.publishedPhotoId
			
		if fsPhotoId then
		
			-- Check to see if the photo is still on Fotosidan.

			if not photosetPhotosSet[ fsPhotoId ] and not isDefaultCollection then
				fsPhotoId = nil
			end
			
		end
		
			
		fsPhotoIdsForRenditions[ rendition ] = fsPhotoId
	
	end

	-- Iterate through photo renditions.
	
	for i, rendition in exportContext:renditions { stopIfCanceled = true } do
	
		-- Update progress scope.
		
		progressScope:setPortionComplete( ( i - 1 ) / nPhotos )
		
		-- Get next photo.

		local photo = rendition.photo

		-- See if we previously uploaded this photo.

		local fsPhotoId = fsPhotoIdsForRenditions[ rendition ]
		
		if not rendition.wasSkipped then

			local success, pathOrMessage = rendition:waitForRender()
			
			-- Update progress scope again once we've got rendered photo.
			
			progressScope:setPortionComplete( ( i - 0.5 ) / nPhotos )
			
			-- Check for cancellation again after photo has been rendered.
			
			if progressScope:isCanceled() then break end
			
			if success then
	

				-- Build up common metadata for this photo.
				
				local title = getFotosidanTitle( photo, exportSettings, pathOrMessage )
		
				local description = photo:getFormattedMetadata( 'caption' )
				local keywordTags = photo:getFormattedMetadata( 'keywordTagsForExport' )
				
				local tags
				
				if keywordTags then

					tags = {}

					local keywordIter = string.gfind( keywordTags, "[^,]+" )

					for keyword in keywordIter do
					
						if string.sub( keyword, 1, 1 ) == ' ' then
							keyword = string.sub( keyword, 2, -1 )
						end
						
						if string.find( keyword, ' ' ) ~= nil then
							keyword = '"' .. keyword .. '"'
						end
						
						tags[ #tags + 1 ] = keyword

					end

				end
				
				-- Fotosidan will pick up LR keywords from XMP, so we don't need to merge them here.
				
				local hidden = exportSettings.hideFromPublic and 2 or 1
				
				-- Because it is common for Fotosidan users (even viewers) to add additional tags via
				-- the Fotosidan web site, so we should not remove extra keywords that do not correspond
				-- to keywords in Lightroom. In order to do so, we record the tags that we uploaded
				-- this time. Next time, we will compare the previous tags with these current tags.
				-- We use the difference between tag sets to determine if we should remove a tag (i.e.
				-- it was one we uploaded and is no longer present in Lightroom) or not (i.e. it was
				-- added by user on Fotosidan and never was present in Lightroom).
				
				local previous_tags = photo:getPropertyForPlugin( _PLUGIN, 'previous_tags' ) 

				local unmanipulated = photo:getPropertyForPlugin( _PLUGIN, 'unmanipulated' ) 
				local equipment     = photo:getPropertyForPlugin( _PLUGIN, 'equipment' ) 
				local bgcolor       = photo:getPropertyForPlugin( _PLUGIN, 'bgcolor' ) 
				local license       = photo:getPropertyForPlugin( _PLUGIN, 'license' ) 
	
				-- Upload or replace the photo.
				
				local didReplace = not not fsPhotoId
				
				local addToPhotostream = booleanToNumber(isDefaultCollection)

				fsPhotoId = FotosidanAPI.uploadPhoto( exportSettings, {
				    photo_id = fsPhotoId,
				    filePath = pathOrMessage,
				    title = title or '',
				    description = description,
				    tags = table.concat( tags, ',' ),
				    add_to_photostream = addToPhotostream,
				    hidden = hidden,
				    unmanipulated = unmanipulated,
				    equipment = equipment,
				    bgcolor = bgcolor,
				    license = license,
				    photoset_id = photosetId,
				} )
				
				FotosidanAPI.setImageTags( exportSettings, {
				    photo_id = fsPhotoId,
				    tags = table.concat( tags, ',' ),
				    previous_tags = previous_tags,
				} )
				
				-- When done with photo, delete temp file. There is a cleanup step that happens later,
				-- but this will help manage space in the event of a large upload.
					
				LrFileUtils.delete( pathOrMessage )
	
				-- Remember this in the list of photos we uploaded.
	
				uploadedPhotoIds[ #uploadedPhotoIds + 1 ] = fsPhotoId

				-- If this isnt the Photostream, set up the photoset.
				
				if not photosetUrl then
	
					if not isDefaultCollection then
	
						-- Create or update this photoset.
	
						photosetId, photosetUrl = FotosidanAPI.createOrUpdatePhotoset( exportSettings, {
										photosetId = photosetId,
										title = publishedCollectionInfo.name,
										--		description = ??,
										primary_photo_id = uploadedPhotoIds[ 1 ],
										type = publishedCollectionInfo.albumType,
										access = publishedCollectionInfo.albumAccess,
									} )
				
					else
	
						-- Photostream: find the URL.
	
						photosetUrl = FotosidanAPI.constructPhotostreamURL( exportSettings )
	
					end
					
				end


				-- Record this Fotosidan ID with the photo so we know to replace instead of upload.
					

				if publishedCollectionInfo then	
					rendition:recordPublishedPhotoId( fsPhotoId )
				end

				local photoUrl
							
				if ( not isDefaultCollection ) then
					
					photoUrl = FotosidanAPI.constructPhotoURL( exportSettings, {	
											photo_id = fsPhotoId,
											photosetId = photosetId,
										} )	
										
					-- Add the uploaded photos to the correct photoset.

--					FotosidanAPI.addPhotosToSet( exportSettings, {
--									photoId = fsPhotoId,
--									photosetId = photosetId,
--								} )
					
				else
					
					photoUrl = FotosidanAPI.constructPhotoURL( exportSettings, {
											photo_id = fsPhotoId,
										} )
										

				end
					
				if publishedCollectionInfo then	
					rendition:recordPublishedPhotoUrl( photoUrl )
				end


				-- Because it is common for Fotosidan users (even viewers) to add additional tags
				-- via the Fotosidan web site, so we can avoid removing those user-added tags that
				-- were never in Lightroom to begin with. See earlier comment.
				
				photo.catalog:withPrivateWriteAccessDo( function()
										photo:setPropertyForPlugin( _PLUGIN, 'previous_tags', table.concat( tags, ',' ) ) 
									end )
			
			end
		
		else
		
			if publishedCollectionInfo then
				-- To get the skipped photo out of the to-republish bin.
				rendition:recordPublishedPhotoId(rendition.publishedPhotoId)
			end
			
		end

	end
	
	if #uploadedPhotoIds > 0 and publishedCollectionInfo then
	
		if ( not isDefaultCollection ) then
			
			exportSession:recordRemoteCollectionId( photosetId )
					
		end
	
		-- Set up some additional metadata for this collection.

		exportSession:recordRemoteCollectionUrl( photosetUrl )
		
	end

	progressScope:done()

	
end

--------------------------------------------------------------------------------

if Debug then
  exportServiceProvider.processRenderedPhotos = Debug.showErrors(exportServiceProvider.processRenderedPhotos)
end
return exportServiceProvider
