; This is the configuration file for Bot.au3
; Please follow the instructions carefully :)

Global Const $SERVER = "" ; IP or Hostname of the IRC Server.
Global Const $PORT = "" ; Port of the IRC Server to connect. (SSL PORTS ARE NOT SUPPORTED!!!)
Global Const $TIMEOUT = 42000 ; TCP Timeout to use in milliseconds. (Its recommended to keep 42000 ms [42 secs])

Global Const $USERNAME = "" ; Sepcify your bot's username here (not the nickname).
Global Const $PASSWORD = "" ; Password of your bot's account.

Global Const $NICKNAME = "" ; Specify your bot's nickname here.
Global Const $REALNAME = "" ; Specify a real (or fake) name for your bot.

Global Const $CHANNELS[0] = [] ; Specify any channel(s) in which the bot will join. Make sure that you don't forgot to change the number of elements.

Global $g_sBotFunction = "_Bot_DefaultBotFunction" ; The bot function...

Global $g_oOpUsers = ObjCreate("Scripting.Dictionary")
Global $g_oAdminUsers = ObjCreate("Scripting.Dictionary")

$g_oAdminUsers.Add("", "") ; Specify your hostname in the first parameter, you can leave. You can add more Admins if you want