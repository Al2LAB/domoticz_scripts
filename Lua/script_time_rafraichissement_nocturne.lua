--[[
name : script_time_rafraichissement_nocturne.lua
auteur : papoo
MAJ : 28/04/2018
création : 24/06/2017

http://pon.fr/rafraichissement-nocturne/
http://easydomoticz.com/forum/viewtopic.php?f=17&t=4343#p38107
Principe : ce script vérifie toutes les dix minutes si la température extérieure (variable temp_ext) passe en dessous de la température  des pièces référencées dans le tableau les_températures. 
il compare chaque température au seuil fixé par la variable  seuil_notification (en °). Si une ou plusieurs températures sont supérieures à ce seuil, envoie d'une notification pour chacune d'elle.
une seule notification par jour, réinitialisée en cours d'après midi, la période la plus chaude de la journée.
Plusieurs type de notifications, par mail, par pushbullet, sms free ou via les notifications de domoticz.
Création de la variable utilisateur de réinitialisation automatique.
tableau des températures intérieures avec définition du nombre de pièces au dessus de la température extérieure avant envoi de notification (variable Nb_pieces)

]]--
--------------------------------------------
------------ Variables à éditer ------------
-------------------------------------------- 
local debugging = false   	                                    -- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
local url = '127.0.0.1:8080'                                    -- adresse ip domoticz
local seuil_notification = 25 	        	                    -- seuil température intérieure au delà duquel les notifications d'alarme seront envoyées
local deltaT = 2                                                -- Delta T entre T° interieure et T° extérieure avant alarme 
local temp_ext = 'Temperature exterieure' 	                    -- nom de la sonde extérieure
local les_temperatures = {"Temperature 1", "Temperature 2", "Temperature Entree", "Temperature Salon", "Temperature Parents", "Temperature Bureau", "Temperature Cuisine", "Temperature Douche"}; -- Liste de vos sondes intérieures séparées par une virgule
local notif_mail = true                                         -- true si l'on  souhaite être notifié  par mail, sinon false.
local subsystem = nil                                           -- les différentes valeurs de subsystem acceptées sont : gcm;http;kodi;lms;nma;prowl;pushalot;pushbullet;pushover;pushsafer
                                                                -- pour plusieurs modes de notification séparez chaque mode par un point virgule. si subsystem = nil toutes les notifications seront activées.
local notif_all = true                                          -- true si l'on  souhaite être notifié  via le système de notification domoticz, sinon false.
local EmailTo = 'votrer@mail.com'                            -- adresse mail, séparées par ; si plusieurs (pour la notification par mail)
local var_notif = 'Notification_ouverture_fenetres'             -- nom de la variable de limite de notification
local Nb_pieces = 4                                             -- Définissez le nombre de pièces minimum dont la T° est supérieure à la température extérieure avant l'envoi des notifications
local ResetHeure = 14                                           -- Heure à laquelle vous souhaitez réinitialiser les notifications
local ResetMinute = 25                                          -- Minute à laquelle vous souhaitez réinitialiser les notifications
local OS = "linux"                                              -- Définissez l'os sous lequel fonctionne ce script. "linux" ou "windows"
local sms_free_user = nil                                       -- nom d'utilisateur freemobile popur l'envoi d'alerte par SMS, sinon nil 
local sms_free_pass = nil                                       -- mot de passe freemobile popur l'envoi d'alerte par SMS, sinon nil

--------------------------------------------
----------- Fin variables à éditer ---------
--------------------------------------------
local nom_script = 'Rafraîchissement nocturne'
local version = '1.21'
local message = {}
local alarme = 0
local notification = '' 
commandArray = {}
--------------------------------------------
---------------- Fonctions -----------------
--------------------------------------------

--json = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")()  -- For Linux
--curl = '/usr/bin/curl -m 5 -u domoticzUSER:domoticzPSWD '		 	-- ne pas oublier l'espace à la fin


package.path = package.path..";/home/pi/domoticz/scripts/lua/fonctions/?.lua"   -- ligne à commenter en cas d'utilisation des fonctions directement dans ce script
require('fonctions_perso')                                                      -- ligne à commenter en cas d'utilisation des fonctions directement dans ce script

-- ci-dessous les lignes à décommenter en cas d'utilisation des fonctions directement dans ce script( supprimer --[[ et --]])
--[[function voir_les_logs (s, debugging) -- nécessite la variable local debugging
    if (debugging) then 
		if s ~= nil then
        print (s)
		else
		print ("aucune valeur affichable")
		end
    end
end	-- usage voir_les_logs("=========== ".. nom_script .." (v".. version ..") ===========",debugging)
--------------------------------------------
function url_encode(str) -- encode la chaine str pour la passer dans une url 
   if (str) then
   str = string.gsub (str, "\n", "\r\n")
   str = string.gsub (str, "([^%w ])",
   function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   end
   return str
end 
--]]
--------------------------------------------
-------------- Fin Fonctions ---------------
--------------------------------------------
time=os.date("*t")
  
if ((time.min-1) % 10) == 0 then -- Déclenchement du script toutes les 10 minutes en commençant à HH:01 
--if time.min % 1 == 0 then -- pour test
    voir_les_logs("=========== ".. nom_script .." (v".. version ..") ===========",debugging)
	voir_les_logs("--- --- --- seuil de notification ".. seuil_notification .."°C",debugging)
    temperature_exterieure = string.match(otherdevices_svalues[temp_ext], "%d+%.*%d*")
    temperature_exterieure = temperature_exterieure 
    voir_les_logs("--- --- --- Temperature exterieure ".. temperature_exterieure .."°C",debugging)
    
    if var_notif ~= nil then -- le nom de la variable utilisateur a t'il été renseigné ?
        if(uservariables[var_notif] == nil) then -- Création de la variable  car elle n'existe pas
            voir_les_logs("--- --- --- La Variable " .. var_notif .." n'existe pas --- --- --- ",debugging)
            commandArray['OpenURL']=url..'/json.htm?type=command&param=saveuservariable&vname='..url_encode(var_notif)..'&vtype=2&vvalue=0'
            adresse = url_encode(var_notif)
            voir_les_logs("--- --- --- adresse " .. adresse .."  --- --- --- ",debugging);
            voir_les_logs("--- --- --- Création de la Variable " .. var_notif .." manquante --- --- --- ",debugging)
            print('script supendu')
        else
        voir_les_logs("--- --- --- La Variable " .. var_notif .." est à : ".. uservariables[var_notif],debugging)
        notification = uservariables[var_notif] 
            if tonumber(notification) > 0 then
            voir_les_logs("--- --- --- Une notification a déjà été envoyée aujourd\'hui",debugging)
            else 
            voir_les_logs("--- --- --- Aucune notification n\'a été envoyée aujourd\'hui",debugging)
            end
        end  
    else 
        voir_les_logs("--- --- --- Le nom de la variable utilisateur n'a pas été correctement défini",debugging)
    end        
            
    for i,d in ipairs(les_temperatures) do
		
		local v=otherdevices[d]                        
			voir_les_logs("--- --- --- device value "..d.." = "..(v or "nil"),debugging)
            if v~= nil then
			
                if string.match(v, ';')  then
                    v=v:match('^(.-);')
                    voir_les_logs("--- --- --- svalue "..d.." = "..(v or "nil").."°C moins le delta T : "..tonumber(v)-tonumber(deltaT).."°C",debugging)
                    local temp_int = tonumber(v)-tonumber(deltaT)
                else
                    voir_les_logs("--- --- --- svalue "..d.." = "..(v or "nil").."°C moins le delta T : "..tonumber(v)-tonumber(deltaT).."°C",debugging)
                end			
			
				if ((tonumber(v)-tonumber(deltaT)) > tonumber(temperature_exterieure)) and (tonumber(v) > tonumber(seuil_notification)) and  (tonumber(temperature_exterieure) >= (tonumber(seuil_notification)-3)) then
                    alarme = tonumber(alarme) + 1
                    voir_les_logs("--- --- --- Température corrigée : "..(tonumber(v)-tonumber(deltaT)).."°C supérieure à la Température exterieure : "..tonumber(temperature_exterieure).."°C, valeur de la variable alarme : ".. alarme,debugging)
                    table.insert(message, 'température '..d..' : '..v..'°C, supérieure à la température exterieure '.. temperature_exterieure ..'°C et au seuil fixé à '.. seuil_notification ..'°C <br>')
				end
                
			end                                            
	end

	if alarme >= tonumber(Nb_pieces)  then
        if notification == 0 then
        voir_les_logs("--- --- --- valeur de la variable alarme :".. alarme .." supérieure ou égale à la valeur de nbPieces :" ..Nb_pieces,debugging)
            if notif_mail == true then
                voir_les_logs("--- --- --- Nb d'alarme(s) : "..alarme,debugging)
                objet = 'Ouverture fenetres recommandee '..os.date("%H:%M")
                commandArray['SendEmail']= objet..'#'.. table.concat(message)  .. '#' .. EmailTo
                voir_les_logs("--- --- --- Objet:"..objet,debugging)
                voir_les_logs("--- --- --- Corps du message: "..table.concat(message),debugging)
                voir_les_logs("--- --- --- Destinataire: "..EmailTo,debugging)
            else
                voir_les_logs("--- --- --- Notification par mail désactivée",debugging)  
            end -- if notif_mail
               
            if sms_free_user ~= nil and sms_free_pass ~=nil then
                voir_les_logs("--- --- --- Notification SMS free",debugging)            
                commandArray['OpenURL']='https://smsapi.free-mobile.fr/sendmsg?user='.. sms_free_user ..'&pass='.. sms_free_pass ..'&msg=Ouverture des fenetres recommandée la temperature interieure est de '.. temperature_exterieure ..'°C'
            end 
            
            if subsystem ~= nil then
                    commandArray['SendNotification'] = 'Ouverture des fenetres recommandée#la température exterieure est de '.. temperature_exterieure ..'°C#0###'.. subsystem ..''
                elseif notif_all == true then
                    commandArray[#commandArray+1] = {['SendNotification'] = 'Ouverture des fenetres recommandée#la température exterieure est de '.. temperature_exterieure ..'°C'}
                    voir_les_logs("--- --- --- Notification domoticz",debugging) 
                else
                    voir_les_logs("--- --- --- Notification domoticz désactivée",debugging)  
            end --notif_all
                commandArray['Variable:'.. var_notif] = tostring(1) -- mise à jour de la variable utilisateur
                voir_les_logs("--- --- --- Mise à jour de la variable:".. var_notif .." à 1",debugging)
        end
	else
        voir_les_logs("--- --- --- valeur de la variable alarme :".. alarme .." inférieure ou égale à la valeur de nbPieces :" ..Nb_pieces..", pas de notification",debugging)   
    end
    voir_les_logs("========= Fin ".. nom_script .." (v".. version ..") =========",debugging)
end -- if time
if time.hour == ResetHeure and time.min == ResetMinute then
    commandArray['Variable:'.. var_notif] = tostring(0) -- mise à jour de la variable utilisateur 
    voir_les_logs("=========== ".. nom_script .." (v".. version ..") ===========",debugging)
    voir_les_logs("--- --- --- Mise à jour de la variable:".. var_notif .." à 0",debugging)
    voir_les_logs("========= Fin ".. nom_script .." (v".. version ..") =========",debugging)
end
return commandArray
