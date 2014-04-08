--[[----------------------------------------------------------------------------

FotosidanMetadataDefinition.lua
Custom metadata definition for Fotosidan publish plug-in

--------------------------------------------------------------------------------

Built on the Lightroom SDK sample plugin for Flickr:
ADOBE SYSTEMS INCORPORATED
 Copyright 2009-2010 Adobe Systems Incorporated
 All Rights Reserved.

NOTICE: Adobe permits you to use, modify, and distribute this file in accordance
with the terms of the Adobe license agreement accompanying it. If you have received
this file from a source other than Adobe, then your use, modification, or distribution
of it requires the prior written permission of Adobe.

------------------------------------------------------------------------------]]

return {

    metadataFieldsForPhotos = {
	
	{
	    id = 'previous_tags',
	    dataType = 'string',
	},

	{
	    id = 'equipment',
	    title='Utrustning',
	    dataType = 'string',
	},

	{
	    id = 'unmanipulated',
	    title='Bearbetning',
	    dataType = 'enum',
	    values = {
		{
		    value = nil,
		    title = 'Ingen uppgift',
		},
		{
		    value = '0',
		    title = 'Manipulerad',
		},
		{
		    value = '1',
		    title = 'Ej manipulerad',
		},

	    },
	},

	{
	    id = 'bgcolor',
	    title='Bakgrundsfärg',
	    dataType = 'enum',
	    values = {

		{
		    value = nil,
		    title = 'Ej spec',
		},
		{
		    value = 'W',
		    title = 'Vit',
		},
		{
		    value = 'G',
		    title = 'Grå',
		},
		{
		    value = 'B',
		    title = 'Svart',
		},

	    },
	},

	{
	    id = 'license',
	    dataType = 'enum',
	    title = 'Licens',
	    values = {

		{
		    value = nil,
		    title = '(FS-inställning)',
		},
		{
		    value = "all",
		    title = 'Alla res.',
		},
		{
		    value = 'cc',
		    title = 'CC BY',
		},
		{
		    value = 'cc-sa',
		    title = 'CC BY-SA',
		},
		{
		    value = 'cc-nd',
		    title = 'CC BY-ND',
		},
		{
		    value = 'cc-nc',
		    title = 'CC BY-NC',
		},
		{
		    value = 'cc-nc-sa',
		    title = 'CC BY-NC-SA',
		},
		{
		    value = 'cc-nc-nd',
		    title = 'CC BY-NC-ND',
		},

	    },


	},







    },
	
schemaVersion = 4, -- must be a number, preferably a positive integer
	
}
