--[[
    
source : https://github.com/vzwingma/domotique/blob/master/domoticz/scripts/lua/script_time_network_status.lua
https://blog.tetsumaki.net/articles/2015/10/recuperation-dinformations-livebox-play.html
https://easydomoticz.com/forum/viewtopic.php?f=10&t=3825&start=10#p35974
https://easydomoticz.com/forum/viewtopic.php?f=17&t=5762&p=50983
http://pon.fr/network-status-via-Livebox-en-lua/

MAJ : 14/04/2018
--]]
--------------------------------------------
------------ Variables � �diter ------------
-------------------------------------------- 
local nom_script = "Livebox Network Status"
local version = "1.5"
local debugging = false  	    -- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
local script_actif = true       -- active (true) ou d�sactive (false) ce script simplement
local delai = 5                         -- d�lai d'ex�cution de ce script en minutes de 1 � 59

-- Cr�er une variable "Livebox_mac_adress_smartphones" avec les MAC ADDRESS des smartphones. Le s�parateur est ";"
livebox_mac_adress_smartphones = uservariables["livebox_mac_adress_smartphones"]

livebox_mac_adress_surveillance = uservariables["livebox_mac_adress_surveillance"]
livebox_mac_adress_smartphones = livebox_mac_adress_smartphones .. livebox_mac_adress_surveillance

-- Cr�er une variable "Livebox_mac_adress_surveillance" avec les MAC ADDRESS des smartphones N' entrant PAS en compte pour l'alarme. Le s�parateur est ";"

--------------------------------------------
----------- Fin variables � �diter ---------
--------------------------------------------
local patternMacAdresses = string.format("([^%s]+)", ";")
local chemin_tmp = "/home/pi/domoticz/Trend/"
--local chemin_tmp = "/home/pi/domoticz/scripts/sh/livebox/"
--------------------------------------------
---------------- Fonctions -----------------
--------------------------------------------   
function voir_les_logs (s, debugging) -- n�cessite la variable local debugging
    if (debugging) then 
		if s ~= nil then
        print ("<font color='#f3031d'>".. s .."</font>")
		else
		print ("<font color='#f3031d'>aucune valeur affichable</font>")
		end
    end
end	-- usage voir_les_logs("=========== ".. nom_script .." (v".. version ..") ===========",debugging)
--==============================================================================================
function readAll(file)
    local f = io.open(file, "rb")
	if(f == nil) then
		return ""
	else
		local content = f:read("*all")
		f:close()
		return content
	end
end
--==============================================================================================
function getPeripheriquesConnectes() -- liste les p�riph�riques utilis�s pour l'activation/d�sactivation automatique de l'alarme
	--local TMP_PERIPHERIQUES = "/home/pi/domoticz/Trend/peripheriques.tmp"
    
    
	--local TMP_PERIPHERIQUES = "/home/pi/domoticz/scripts/sh/livebox/Devices.txt"
    local TMP_PERIPHERIQUES = chemin_tmp .."Devices.txt"

	--  Appel sur la liste des p�riph�riques
	voir_les_logs("Recherche des p�riph�riques connus de la Livebox",debugging)

	local json_peripheriques = JSON:decode(readAll(TMP_PERIPHERIQUES))
	local etatSmartphone = false
	-- Liste des p�riph�riques
	for index, peripherique in pairs(json_peripheriques.status) do
        --voir_les_logs("--- --- --- [Livebox] Statut du peripherique surveillance " .. index .. " :: " .. peripherique.Key,debugging)
		for mac in string.gmatch(livebox_mac_adress_smartphones, patternMacAdresses) do
			if(mac == peripherique.Key) then
			    if(peripherique.Active) then
					-- local lastChanged = os.time() - convertStringUTCTimeToSeconds(peripherique.LastChanged)
					-- local lastConnect = os.time() - convertStringUTCTimeToSeconds(peripherique.LastConnection)
					-- if(lastChanged < 0) then
						-- lastChanged = 0
                    -- end                
				voir_les_logs("Statut du peripherique en surveillance ".. peripherique.Name.." [" .. mac .. "]  =>  actif:" .. tostring((peripherique.Active)),debugging)
                --voir_les_logs("--- --- --- [" .. peripherique.Name .. "] actif; Derni�re activite = " .. peripherique.LastChanged .. " :: " .. lastChanged .. "s / Derni�re connexion = " .. peripherique.LastConnection .. " :: " .. lastConnect .. "s",debugging)
                    
					etatSmartphone = true
                        if otherdevices[peripherique.Name] == 'Off' then
							commandArray [peripherique.Name]='On'
                            voir_les_logs("--- --- --- [Livebox] Activation de : " .. peripherique.Name .."  --- --- --- ",debugging)
						
                        end
							else
                        if otherdevices[peripherique.Name] == 'On' then    
							commandArray [peripherique.Name]='Off'
                            voir_les_logs("--- --- --- [Livebox] DesActivation de : " .. peripherique.Name .."  --- --- --- ",debugging)
						
                        end   
				end		
			end
		end
	end
return etatSmartphone
end
--==============================================================================================	
function getPeripheriquesConnectes2() -- liste les p�riph�riques utilis�s pour
	--local TMP_PERIPHERIQUESHORSALARME = "/home/pi/domoticz/Trend/peripheriques_hors_alarme.tmp"
	--  Appel sur la liste des p�riph�riques
	voir_les_logs("Recherche des peripheriques connus de la Livebox (hors alarme)",debugging)
	-- local commandeurl="curl -s -H \"Content-Type: application/json\" -H \"X-Fbx-App-Auth: " .. session_token .. "\" -X GET " .. apiLiveboxv4 .. "/lan/browser/pub/"
	-- os.execute(commandeurl .. " > " .. TMP_PERIPHERIQUESHORSALARME)
   
    
	local TMP_PERIPHERIQUESHORSALARME = chemin_tmp .."Devices.txt"
	local other_json_peripheriques = JSON:decode(readAll(TMP_PERIPHERIQUESHORSALARME))
	other_etatPeripheriques = false
    -- Liste des p�riph�riques HORS ALARME
	for index, peripherique in pairs(other_json_peripheriques.status) do
        voir_les_logs("--- --- --- [Livebox] Statut du peripherique hors surveillance " .. index .. " :: " .. peripherique.Key,debugging)
		for mac in string.gmatch(livebox_mac_adress_smartphones, patternMacAdresses) do
			if(mac == peripherique.Key)
			then
				voir_les_logs("Statut du peripherique hors surveillance".. peripherique.Name.." [" .. mac .. "]  =>  actif:" .. tostring((peripherique.Active)),debugging)
				if(peripherique.Active) then
                other_etatPeripheriques = true
                    if otherdevices[peripherique.Name] == 'Off' then
                        commandArray [peripherique.Name]='On'
                        voir_les_logs("--- --- --- [Livebox] Activation de : " .. peripherique.Name .."  --- --- --- ",debugging)
                    end
				else
                    if otherdevices[peripherique.Name] == 'On' then    
                        commandArray [peripherique.Name]='Off'
                        voir_les_logs("--- --- --- [Livebox] DesActivation de : " .. peripherique.Name .."  --- --- --- ",debugging)
                    end
				end		
			end
		end
	end	
return other_etatPeripheriques
end
-- Mise � jour de l'alarme suivant le statut des p�riph�riques
-- @param : �tat des p�riph�riques
--==============================================================================================	
function updateAlarmeStatus(etat_peripheriques)
	local etatActuelAlarme=otherdevices['Security Panel']
    voir_les_logs("  > Etat du panneau de securite = " .. etatActuelAlarme ,debugging)
	local SEUIL_ALARME = 1 -- temps en minute avant activation de l'alarme
	local TMPDIR_COMPTEUR_OUT = "/home/pi/domoticz/Trend/compteur_smartphone_out.tmp"
	-- Activation de l'alarme au bout de X min
	if(not etat_peripheriques and etatActuelAlarme == "Normal") then
    --if(not etat_peripheriques) then
		compteurOff=readAll(TMPDIR_COMPTEUR_OUT)
		if(compteurOff == "") then
			compteurOff = 0
		end
		compteurOff = compteurOff + 1
		voir_les_logs("  > Compteur de mise en alarme = " .. compteurOff .. " / " .. SEUIL_ALARME,debugging)
		if(compteurOff >= SEUIL_ALARME) then
			voir_les_logs("Activation de l'alarme",debugging)
            commandArray[#commandArray+1] = {['Alarme Out']="On"}
            commandArray[#commandArray+1] = {['test presences']="Off"}          
			compteurOff = 0
		end
		os.execute("echo " .. compteurOff .. " > " .. TMPDIR_COMPTEUR_OUT)
	elseif(etat_peripheriques and etatActuelAlarme == "Arm Away") then
    -- D�sactivation imm�diate
		
        commandArray[#commandArray+1] = {['Alarme Out']="On"}
        commandArray[#commandArray+1] = {['test presences']="On"}
		voir_les_logs("D�sactivation de l'alarme",debugging)

		os.execute("echo 0 > " .. TMPDIR_COMPTEUR_OUT)
	
	elseif(etat_peripheriques) then
		os.execute("echo 0 > " .. TMPDIR_COMPTEUR_OUT)
        commandArray[#commandArray+1] = {['test presences']="On"}
        voir_les_logs("Remise a zero du compte de l'alarme",debugging)
		
	end	
end
--------------------------------------------
-------------- Fin Fonctions ---------------
--------------------------------------------
commandArray = {}
time=os.date("*t")
if ((time.min-1) % delai) == 0 and script_actif == true then -- toutes les x minutes en commen�ant par xx:01.  x d�finissable via la variable delai (sauf � xx:00)
		voir_les_logs("[Livebox] Statuts des p�riph�riques r�seau Livebox",debugging)
	-- Boucle principale
 	if ( livebox_mac_adress_surveillance == nil or livebox_mac_adress_surveillance == nil ) then
		--error("[Livebox] {livebox_mac_adress_smartphones}, {livebox_mac_adress_surveillance} ne sont pas d�finies dans Domoticz")
		--return 512
        print("erreur")
	else
		voir_les_logs("Test de pr�sence des appareils d'adresses MAC (" .. livebox_mac_adress_smartphones .. ")",debugging)
        voir_les_logs("Test de pr�sence des appareils d'adresses MAC (" .. livebox_mac_adress_surveillance .. ")",debugging)
		JSON = (loadfile "/home/pi/domoticz/scripts/lua/JSON.lua")() -- one-time load of the routines
		-- Connexion � la Livebox
		--connectToLivebox()
		-- Recherche des p�riph�riques connect�s
        os.execute('sudo bash /home/pi/domoticz/scripts/sh/livebox/livebox.sh') 
		peripheriques_up = getPeripheriquesConnectes()
		-- Recherche des p�riph�riques connect�s  (HORS ALARME)
		--getPeripheriquesConnectes2()
		--updateAlarmeStatus(peripheriques_up)
		-- D�connexion � la Livebox
		--disconnectToLivebox()
	end
end --if time	
return commandArray
