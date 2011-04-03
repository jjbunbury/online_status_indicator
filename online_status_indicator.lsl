// $Rev: 38 $
//
// TODO
// - Assign random channel to message sending function
// - Store notecards and message until owner is online (if they are currently offline).
// - ^ Perhaps should be optional. I get offline IMs and such, so I personally prefer to get them instantly.
// - We need timer variables so we can leave updates running while the menu is open, etc.

// Variables
list MENU_COMMANDS            = ["Profile", "Message", "CLOSE"];
list MENU_ADMIN               = ["Update"];
integer MENU_CHANNEL          = -97157;
integer MESSAGE_CHANNEL       = 72;
string URL                    = "http://world.secondlife.com/resident/";
key BLANK_TEXTURE             = "5748decc-f629-461c-9a36-a35a221fe21f";
string PROFILE_KEY            = "<meta name=\"imageid\" content=\"";
string PROFILE_IMAGE          = "<img alt=\"profile image\" src=\"http://secondlife.com/app/image/";
string Z_SPACER               = "\n \n \n \n \n";
string ONLINE_MESSAGE         = "{0} is Online{1}";
string OFFLINE_MESSAGE        = "{0} is Offline{1}";
string WAIT_MESSAGE           = "Please Wait...{0}";
vector GREEN                  = <0.0, 1.0, 0.0>;
vector RED                    = <1.0, 0.0, 0.0>;
vector WHITE                  = <1.0, 1.0, 1.0>;
string PROFILE_LINK           = "secondlife:///app/agent/{0}/about";
integer PROFILE_KEY_LENGTH;   // calculated from profile_key_prefix in state_entry()
integer PROFILE_IMAGE_LENGTH; // calculated from profile_key_prefix in state_entry()

key profile_texture           = NULL_KEY;
string owner_name;
key owner_key;
key online_check;
integer is_online;
integer message_listen_handle;
integer menu_listen_handle;

string format(string text, list args)
{
    integer len=(args!=[]);
    if(len==0)
    {
        return text;
    }
    else
	{
        string ret=text;
        integer i;
        for(i=0;i<len;i++)
        {
            integer pos=llSubStringIndex(ret,"{"+(string)i+"}");
            if(pos!=-1)
            {
                ret=llDeleteSubString(ret,pos,pos+llStringLength("{"+(string)i+"}")-1);
                ret=llInsertString(ret,pos,llList2String(args,i));
            }
            else
            {
                return text;
			}
		}
		return ret;
	}
}

set_color(vector PANEL_COLOR)
{
	integer i;
    for (i=1;i<5;i++)
	{
        llSetColor(PANEL_COLOR, i);
        llSetTexture(BLANK_TEXTURE, i);
    }
}

update()
{
    if (is_online)
	{
        llSetText(format(ONLINE_MESSAGE, [owner_name, Z_SPACER]), GREEN, 1.0);
        set_color(GREEN);
    }
	else
	{
        llSetText(format(OFFLINE_MESSAGE, [owner_name, Z_SPACER]), RED, 1.0);
        set_color(RED);
    }
}

get_image()
{
	// Don't bother if we already have a texture.
	if (profile_texture == NULL_KEY)
	{
		llHTTPRequest(URL + (string) owner_key, [HTTP_METHOD,"GET"], "");
	}
}

set_texture(key texture)
{
	profile_texture = texture;

	if (profile_texture == NULL_KEY)
	{
		llSetTexture(BLANK_TEXTURE, 0);
	}
	else
	{
		llSetTexture(profile_texture, 0);
	}
}

default
{
    state_entry()
	{
		llSetText(format(WAIT_MESSAGE, [Z_SPACER]), WHITE, 1.0);

        owner_key  = llGetOwner();
        owner_name = llKey2Name(owner_key);        
        
		set_texture(NULL_KEY);
		set_color(WHITE);
        
		PROFILE_KEY_LENGTH   = llStringLength(PROFILE_KEY);
        PROFILE_IMAGE_LENGTH = llStringLength(PROFILE_IMAGE);

		// TODO: Processes dropped notecards, etc.
        // llAllowInventoryDrop(TRUE);
        llSetTimerEvent(10);
    }
    
    timer()
	{
		llListenRemove(menu_listen_handle);
		llListenRemove(message_listen_handle);
		llSetTimerEvent(10);
        online_check = llRequestAgentData(owner_key, DATA_ONLINE);
        get_image();
    }

	changed(integer change)
	{
		if (change & CHANGED_INVENTORY)
		{
			string script_name = llGetScriptName();
			integer inventory_count = llGetInventoryNumber(INVENTORY_ALL);
			integer inventory_index;
			for (inventory_index = inventory_count; inventory_index >= 0; --inventory_index)
			{
				string inventory_name = llGetInventoryName(INVENTORY_ALL, inventory_index);
				if (inventory_name != script_name)
				{
					integer inventory_type = llGetInventoryType(inventory_name);
					if (inventory_type != INVENTORY_NOTECARD)
					{
						llSay(0, "Only notecards are allowed for sending.");
						llRemoveInventory(inventory_name);
					}
					else
					{
						llSay(0, "Thank you for the notecard.  I'll make sure it gets delivered!");
						llGiveInventory(owner_key, inventory_name);
						llRemoveInventory(inventory_name);
					}
				}
			}
		}
	}
    
    dataserver(key check, string data)
	{
        if (check == online_check)
		{
			// Only update if there is a change.
            if (is_online != (integer) data)
			{
                is_online = (integer) data;
                update();
            }
        }
    }
    
    on_rez(integer start_param)
	{
        llResetScript();
    }
    
    touch_start(integer num_touched)
	{
        integer i;
        for (i=0; i<num_touched; i++)
		{
            key toucher_key = llDetectedKey(i);
			list menu_entries;
            
			if (toucher_key == owner_key)
			{
				menu_entries = MENU_COMMANDS + MENU_ADMIN;
			}
			else
			{
				menu_entries = MENU_COMMANDS;
			}

			menu_listen_handle = llListen(MENU_CHANNEL, "", "", "");
			llDialog(toucher_key, "Actions", menu_entries, MENU_CHANNEL);
			llSetTimerEvent(60);
        }
    }

	listen(integer channel, string name, key id, string message)
	{
		if (channel == MENU_CHANNEL)
		{
			llListenRemove(menu_listen_handle);
			if (message == "CLOSE")
			{
				// Done.
				llSetTimerEvent(10);
			}
			else if (message == "Profile")
			{
				llSay(0, "Profile link for "+owner_name+". You may need to open local chat (Ctrl-H).");
				llSay(0, format(PROFILE_LINK, [(string) owner_key]));
				llSetTimerEvent(10);
			}
			else if (message == "Message")
			{
				message_listen_handle = llListen(MESSAGE_CHANNEL, "", "", "");
				llSay(0, "Leave your message using channel 72. Example: /72 Hello there!");
				llSetTimerEvent(60);
			}
			else if (message == "Update")
			{
				llOwnerSay("Profile image will be updated. (Can take up 30 seconds)");
				profile_texture == NULL_KEY;
				llSetTimerEvent(1);
			}
		}
		else if (channel == MESSAGE_CHANNEL)
		{
			llListenRemove(message_listen_handle);
			llSay(0, "Thank you for the message.  I will ensure that it is delivered!");
			llInstantMessage(owner_key, message);
			llSetTimerEvent(10);
		}
	}
    
    http_response(key request_id, integer status, list metadata, string body)
    {
        integer start_pos = llSubStringIndex(body, PROFILE_KEY);
        integer end_pos = PROFILE_KEY_LENGTH;

        if(start_pos == -1)
		{
            start_pos = llSubStringIndex(body, PROFILE_IMAGE);
            end_pos = PROFILE_IMAGE_LENGTH;
        }
 
        if(start_pos == -1)
		{
			set_texture(NULL_KEY);
        }
		else
		{
            start_pos += end_pos;
			end_pos = start_pos + 35;
            set_texture(llGetSubString(body, start_pos, end_pos));
        }
    }
}
