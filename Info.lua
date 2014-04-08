--[[----------------------------------------------------------------------------

Info.lua
Summary information for Fotosidan sample plug-in

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

return {

	VERSION = { major=1, minor=3, revision=0, build=0, },

	LrSdkVersion = 4.0,
	LrSdkMinimumVersion = 3.0, -- minimum SDK version required by this plug-in

	LrToolkitIdentifier = 'se.fotosidan.lightroom.export',
	LrPluginName = LOC "$$$/Fotosidan/PluginName=Fotosidan",
	
	LrExportServiceProvider = {
		title = LOC "$$$/Fotosidan/Fotosidan-title=Fotosidan",
		file = 'FotosidanExportServiceProvider.lua',
	},
	
	LrMetadataProvider = 'FotosidanMetadataDefinition.lua',

	LrMetadataTagsetFactory = {
		'FotosidanMetadataTagset.lua',
	},




}
