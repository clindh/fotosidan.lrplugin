--[[----------------------------------------------------------------------------

FotosidanPublishServiceProvider.lua
Publish-specific portions of Lightroom Fotosidan uploader

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

local LrDialogs = import 'LrDialogs'

require 'FotosidanAPI'

local logger = import 'LrLogger'( 'FotosidanPlugin' )
logger:enable("logfile")

local LrTasks                   = import 'LrTasks'

-- local Require = require 'Require'.path ("../debugscript.lrdevplugin")
-- require 'strict'
-- local Debug = require 'Debug'.init ()

local publishServiceProvider = {}

publishServiceProvider.small_icon = 'small_fotosidan.png'

publishServiceProvider.publish_fallbackNameBinding = 'fullname'

publishServiceProvider.titleForPublishedCollection = LOC "$$$/Fotosidan/TitleForPublishedCollection=Samling"
publishServiceProvider.titleForPublishedCollection_standalone = LOC "$$$/Fotosidan/TitleForPublishedCollection/Standalone=Samling"
publishServiceProvider.titleForPublishedCollectionSet = LOC "$$$/Fotosidan/TitleForPublishedCollectionSet=Samlingsuppsättning" 
publishServiceProvider.titleForPublishedCollectionSet_standalone = LOC "$$$/Fotosidan/TitleForPublishedCollectionSet/Standalone=Samlingsuppsättning" 
publishServiceProvider.titleForPublishedSmartCollection = LOC "$$$/Fotosidan/TitleForPublishedSmartCollection=Smart samling"
publishServiceProvider.titleForPublishedSmartCollection_standalone = LOC "$$$/Fotosidan/TitleForPublishedSmartCollection/Standalone=Smart samling"

function publishServiceProvider.getCollectionBehaviorInfo( publishSettings )
	return {
		defaultCollectionName = LOC "$$$/Fotosidan/DefaultCollectionName/Photostream=Nya bilder",
		defaultCollectionCanBeDeleted = true,
		canAddCollection = true,
 		maxCollectionSetDepth = 1,
	}
end

publishServiceProvider.titleForGoToPublishedCollection = LOC "$$$/Fotosidan/TitleForGoToPublishedCollection=Redigera på Fotosidan"
publishServiceProvider.titleForGoToPublishedPhoto = LOC "$$$/Fotosidan/TitleForGoToPublishedCollection=Redigera på Fotosidan"

--[[ Not used for Fotosidan plug-in.

function publishServiceProvider.goToPublishedCollection( publishSettings, info )
end

--]]



--[[ Not used for Fotosidan plug-in.

function publishServiceProvider.goToPublishedPhoto( publishSettings, info )
end

]]--

function publishServiceProvider.metadataThatTriggersRepublish( publishSettings )

	return {

		default = false,
		title = true,
		caption = true,
		keywords = true,
		gps = true,
		dateCreated = true,

		['se.fotosidan.lightroom.export.equipment'] = true,	
		['se.fotosidan.lightroom.export.unmanipulated'] = true,	
		['se.fotosidan.lightroom.export.bgcolor'] = true,	
		['se.fotosidan.lightroom.export.license'] = true,	

	}

end


function publishServiceProvider.shouldReverseSequenceForPublishedCollection( publishSettings, collectionInfo )
	return false
end

publishServiceProvider.supportsCustomSortOrder = true
	
function publishServiceProvider.imposeSortOrderOnPublishedCollection( publishSettings, info, remoteIdSequence )

	local photosetId = info.remoteCollectionId

	if photosetId then

		-- Get existing list of photos from the photoset. We want to be sure that we don't
		-- remove photos that were posted to this photoset by some other means by doing
		-- this call, so we look for photos that were missed and reinsert them at the end.

		local existingPhotoSequence = FotosidanAPI.listPhotosFromPhotoset( publishSettings, { photosetId = photosetId } )

		-- Make a copy of the remote sequence from LR and then tack on any photos we didn't see earlier.
		
		local combinedRemoteSequence = {}
		local remoteIdsInSequence = {}
		
		for i, id in ipairs( remoteIdSequence ) do
			combinedRemoteSequence[ i ] = id
			remoteIdsInSequence[ id ] = true
		end
		
		for _, id in ipairs( existingPhotoSequence ) do
			if not remoteIdsInSequence[ id ] then
				combinedRemoteSequence[ #combinedRemoteSequence + 1 ] = id
			end
		end
		
		-- There may be no photos left in the set, so check for that before trying
		-- to set the sequence.
		if existingPhotoSequence and existingPhotoSequence.primary then
			FotosidanAPI.setPhotosetSequence( publishSettings, {
									photosetId = photosetId,
									primary = existingPhotoSequence.primary,
									photoIds = combinedRemoteSequence } )
		end
								
	end

end



function publishServiceProvider.deletePhotosFromPublishedCollection( publishSettings, arrayOfPhotoIds, deletedCallback )

	for i, photoId in ipairs( arrayOfPhotoIds ) do

		FotosidanAPI.deletePhoto( publishSettings,
		     { photoId = photoId, suppressErrorCodes = { [ 1 ] = true } } )
		-- If Fotosidan says photo not found, ignore that.

		deletedCallback( photoId )

	end
	
end


function publishServiceProvider.deletePublishedCollection( publishSettings, info )

	import 'LrFunctionContext'.callWithContext( 'publishServiceProvider.deletePublishedCollection', function( context )
	
		local progressScope = LrDialogs.showModalProgressDialog {
			title = LOC( "$$$/Fotosidan/DeletingCollectionAndContents=Deleting ^[^1^]", info.name ),
			functionContext = context
		}
	
		if info and info.photoIds then
		
			for i, photoId in ipairs( info.photoIds ) do
			
				if progressScope:isCanceled() then break end
			
				progressScope:setPortionComplete( i - 1, #info.photoIds )
				FotosidanAPI.deletePhoto( publishSettings, { photoId = photoId } )
			
			end
		
		end

	        local publishedPhotos = info.publishedCollection:getPublishedPhotos()
	
		if info and info.remoteId then
	
			local setInfo = FotosidanAPI.getPhotosetInfo(publishSettings, { photosetId = info.remoteId })
			local setPhotoCount = tonumber(setInfo.photoset.photos)

			if setPhotoCount == #publishedPhotos or setPhotoCount == 0 then
			    FotosidanAPI.deletePhotoset( publishSettings, {
				photosetId = info.remoteId,
			    } )
			else
			    LrDialogs.message(
      LOC "$$$/Fotosidan/DeletingCollectionAndContents/NotDeletedDialog/Title=Albumet på Fotosidan har inte raderats",
      LOC "$$$/Fotosidan/DeletingCollectionAndContents/NotDeletedDialog/Info=Det finns fler foton i albumet på Fotosidan, så det har inte raderats.",
					      "info")
			
		        end
	
		end
			
	end )

end


function publishServiceProvider.getCommentsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, commentCallback )

	if not publishSettings.syncComments then
		return 
	end

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local comments = FotosidanAPI.getComments( publishSettings, {
								photoId = photoInfo.remoteId,
							} )
		
		local commentList = {}
		
		if comments and #comments > 0 then

			for _, comment in ipairs( comments ) do

				table.insert( commentList, {
								commentId = comment.id,
								commentText = comment.commentText,
								dateCreated = comment.datecreate,
								username = comment.author,
								realname = comment.authorname,
								url = comment.permalink
							} )

			end			

		end	

		commentCallback{ publishedPhoto = photoInfo, comments = commentList }						    

	end

end

publishServiceProvider.titleForPhotoRating = LOC "$$$/Fotosidan/TitleForPhotoRating=Favoritmarkeringar"

function publishServiceProvider.getRatingsFromPublishedCollection( publishSettings, arrayOfPhotoInfo, ratingCallback )

	for i, photoInfo in ipairs( arrayOfPhotoInfo ) do

		local rating = FotosidanAPI.getNumOfFavorites( publishSettings, { photoId = photoInfo.remoteId } )
		if type( rating ) == 'string' then rating = tonumber( rating ) end

		ratingCallback{ publishedPhoto = photoInfo, rating = rating or 0 }

	end
	
end

function publishServiceProvider.canAddCommentsToService( publishSettings )

  return publishSettings.syncComments
--  and FotosidanAPI.testFotosidanConnection( publishSettings )

end

function publishServiceProvider.addCommentToPublishedPhoto( publishSettings, remotePhotoId, commentText )

	local success = FotosidanAPI.addComment( publishSettings, {
							photoId = remotePhotoId,
							commentText = commentText,
						} )
	
	return success

end


function publishServiceProvider.viewForCollectionSettings( f, publishSettings, info )

	local collectionSettings = assert( info.collectionSettings )
	local isDefaultCollection = info.isDefaultCollection

        local albumList = FotosidanAPI.getAlbums(publishSettings, true)

	local remoteId
	local pubCollection
	local isEdit = false
	local setinfo
	
	if info.publishedCollection then
                pubCollection = assert( info.publishedCollection )
                remoteId = pubCollection:getRemoteId()
		isEdit = true
		if remoteId then
		    setinfo = FotosidanAPI.getPhotosetInfo( publishSettings, { photosetId = remoteId } )
		    info.name = setinfo.photoset.title
		    collectionSettings.albumType = setinfo.photoset.type
		    collectionSettings.albumAccess = setinfo.photoset.access
		end    
        end
        
	if collectionSettings.albumType == nil then
		collectionSettings.albumType = "st"
	end

	if collectionSettings.albumAccess == nil then
		collectionSettings.albumAccess = "pu"
	end
	
	collectionSettings.albumId = remoteId

	local bind = import 'LrView'.bind

	local userinfo = FotosidanAPI.getUserInfo( publishSettings, { userId = publishSettings.nsid } )

	local albumTypeItems = { { value = 'st', title = FotosidanAPI.mapAlbumType("st") } }

	if userinfo.ispro then
	   albumTypeItems[#albumTypeItems+1] = { value = 'ps', title = FotosidanAPI.mapAlbumType("ps") }
	end

	if userinfo.type == "gold" then
	   albumTypeItems[#albumTypeItems+1]  = { value = 'pf', title = FotosidanAPI.mapAlbumType("pf") }
	end

	local albumAccessItems = { { value = 'pu', title = "Ja" }, { value = 'pr', title = "Nej" }  }

	local infoText = ""

	if remoteId then
		infoText = LOC "$$$/Fotosidan/xx/yy=OBS! Namnändring ovan slår också igenom på Fotosidan"
	elseif not isDefaultCollection then
		infoText = LOC "$$$/Fotosidan/xx/yy=Om namnet ej matchar ett befintligt album skapas ett nytt, opublicerat album"
	end


local infoText1 = "Välj ett album på Fotosidan att koppla mot denna kollektion"
local infoText2 = "Om album ej valts ovan eller om namnet inte matchar ett befintligt, skapas ett nytt med denna inställning:"

if remoteId then
   if collectionSettings.albumId then
     infoText1 = "Kollektionen är kopplad mot ett FS-album. Namnändring ovan ändrar även på Fotosidan."
   else
     infoText1 = ""
   end

   infoText2 = ""
end


	return f:group_box {
		title = "Fotosidan Albuminställningar",  -- this should be localized via LOC
		size = 'small',
		fill_horizontal = 1,
		bind_to_object = assert( collectionSettings ),
		
		f:column {
		    fill_horizontal = 1,
		    spacing = f:label_spacing(),
		    
		    f:static_text {
			title = infoText1,
		    },

		    f:row  {
			f:static_text {
			    title = "FS-album:",
			},

			f:popup_menu {
			    value = bind 'albumId',
			    items = albumList,
			    fill_horizontal = 1,
			    immediate = true,
			    enabled = (isEdit == false),
			},
		    },
		    
		    f:static_text {
			title = infoText2,
		    },

		
		    f:row  {
			f:static_text {
			    title = "Albumtyp:",
			},

			f:popup_menu {
			    value = bind 'albumType',
			    items = albumTypeItems,
			    enabled = (isEdit == false),
			},
		    },

		    f:row  {
			f:static_text {
			    title = "Publicerat:",
			},
			
			f:popup_menu {
			    value = bind 'albumAccess',
			    items = albumAccessItems,
			    },
			},


		    
		},
		
	}

end

function publishServiceProvider.renamePublishedCollection( publishSettings, info )

    LrTasks.startAsyncTask( function()

        local publishedCollection = info.publishedCollection
        local collectionInfo = publishedCollection:getCollectionInfoSummary()
        local collectionSettings = collectionInfo.collectionSettings

	if info.remoteId then

		FotosidanAPI.createOrUpdatePhotoset( publishSettings, {
			photosetId = info.remoteId,
			title = info.name,
		} )

	end
    end)		

end


function publishServiceProvider.updateCollectionSettings( publishSettings, info )


    LrTasks.startAsyncTask( function()

	 local collectionSettings = info.collectionSettings
	 local publishedCollection = info.publishedCollection
	 local remoteId = publishedCollection:getRemoteId()
	 local albumId = collectionSettings.albumId
	 local remoteUrl			    

	 if albumId and not remoteId then
	 	local setinfo = FotosidanAPI.getPhotosetInfo( publishSettings, { photosetId = albumId } )

		publishedCollection.catalog:withWriteAccessDo( "Set Remote ID", function()
	       		publishedCollection:setRemoteId( albumId )
	       		publishedCollection:setName( setinfo.photoset.title._value )
	       		publishedCollection:setRemoteUrl( setinfo.photoset.url )
	     	end)
			    
	 elseif remoteId then
         	remoteId, remoteUrl = FotosidanAPI.createOrUpdatePhotoset( publishSettings, {
			photosetId = remoteId,
	 		title = info.name,
			type = collectionSettings.albumType,
			access = collectionSettings.albumAccess,
			} )

    	 else
		remoteId, remoteUrl = FotosidanAPI.createOrUpdatePhotoset( publishSettings, {
		    title = info.name,
		    type = collectionSettings.albumType,
		    access = collectionSettings.albumAccess,
		} )

		publishedCollection.catalog:withWriteAccessDo( "Set Remote ID", function()
	       		publishedCollection:setRemoteId( remoteId )
	       		publishedCollection:setRemoteUrl( remoteUrl )
	        end)

	end		

    end)

end

--------------------------------------------------------------------------------

FotosidanPublishSupport = publishServiceProvider
