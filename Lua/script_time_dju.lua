--[[   
~/domoticz/scripts/lua/script_time_dju.lua
auteur : papoo
MAJ : 29/12/2017
création : 26/12/2017
Principe :
Calculer, via l'information température d'une sonde extérieure, les DJU "intégrales"
https://easydomoticz.com/forum/viewtopic.php?f=17&t=1876&p=46879#p46879

trouvez le coefficient moyen de conversion Gaz/kwh pour votre commune sur https://www.grdf.fr/particuliers/services-gaz-en-ligne/coefficient-conversion
]]--
--------------------------------------------
------------ Variables à éditer ------------
-------------------------------------------- 
local debugging = true  			        -- true pour voir les logs dans la console log Dz ou false pour ne pas les voir
local temp_ext  = 'Temperature exterieure' 	-- nom de la sonde de température extérieure
local domoticzURL = '127.0.0.1:8080'        -- user:pass@ip:port de domoticz
local var_user_dju = 'dju'                  -- nom de la variable utilisateur de type 2 (chaine) pour le stockage temporaire des données journalières DJU
local compteur_dju_idx = 979 				-- idx du  dummy compteur DJU en °
local heure_raz_var = 23                    -- heure de l'incrémentation du compteur DJU compteur_dju_idx et de remise à zéro de la variable utilisateur var_user_dju
local minute_raz_var = 59                   -- Minute de l'incrémentation du compteur DJU compteur_dju_idx et de remise à zéro de la variable utilisateur var_user_dju

local coef_gaz = 10.83                      -- coefficient moyen gaz pour votre commune
local cpt_gaz = 'Compteur Gaz'              -- idx de votre compteur gaz, nil si vous ne souhaitez pas calculer l'énergie consommée
local cpt_nrj_idx = '985'                     -- idx du dummy compteur nrj, nil si vous ne souhaitez pas totaliser l'énergie consommée en Wh
local compteur_nrj = 'Energie consommée chauffage'
local var_user_gaz = 'conso_gaz'            -- nom de la variable utilisateur de type 2 (chaine) pour le stockage temporaire des données

--------------------------------------------
----------- Fin variables à éditer ---------
-------------------------------------------- 
commandArray = {}
local nom_script = 'Calcul DJU'
local version = '1.14'
local dju
local somme_dju
local conso_gaz
local conso_nrj
local index_nrj
local somme_nrj
local cpt_nrj
time=os.date("*t")
--------------------------------------------
---------------- Fonctions -----------------
-------------------------------------------- 
curl = '/usr/bin/curl -m 15 -u domoticzUSER:domoticzPSWD '
--==============================================================================================
function voir_les_logs (s, debbuging)
    if (debugging) then 
		if s ~= nil then
        print ("<font color='#f3031d'>".. s .."</font>");
		else
		print ("<font color='#f3031d'>aucune valeur affichable</font>");
		end
    end
end	
--==============================================================================================
function round(value, digits)
	if not value or not digits then
		return nil
	end
		local precision = 10^digits
		return (value >= 0) and
		  (math.floor(value * precision + 0.5) / precision) or
		  (math.ceil(value * precision - 0.5) / precision)
end
--==============================================================================================
function calc_dju(temperature)
dju  = tonumber((18 - temperature)*1/1440)
return dju
end
--============================================================================================== 
function url_encode(str) -- encode la chaine str pour la passer dans une url 
   if (str) then
   str = string.gsub (str, "\n", "\r\n")
   str = string.gsub (str, "([^%w ])",
   function (c) return string.format ("%%%02X", string.byte(c)) end)
   str = string.gsub (str, " ", "+")
   end
   return str
end
--============================================================================================== 
function creaVar(vname,vtype,vvalue) -- pour créer une variable de type 2 nommée toto comprenant la valeur 10
	os.execute(curl..'"'.. domoticzURL ..'/json.htm?type=command&param=saveuservariable&vname='..url_encode(vname)..'&vtype='..vtype..'&vvalue='..url_encode(vvalue)..'" &')
end -- usage :  creaVar('toto','2','10')  
--==============================================================================================
-- Obtenir le nom d'un device via son idx
function GetDeviceNameByIDX(deviceIDX) -- https://www.domoticz.com/forum/viewtopic.php?t=18736#p144720
    deviceIDX = tonumber(deviceIDX)
   for i, v in pairs(otherdevices_idx) do
      if v == deviceIDX then
         return i
      end
   end
   return 0
end -- exemple usage = commandArray[GetDeviceNameByIDX(383)] = 'On'
--==============================================================================================
-- Obtenir l'idx d'un device via son nom
function GetDeviceIdxByName(deviceName) 
   for i, v in pairs(otherdevices_idx) do
      if i == deviceName then
         return v
      end
   end
   return 0
end -- exemple usage = commandArray['UpdateDevice'] = GetDeviceIdxByName('Compteur Gaz') .. '|0|' .. variable
--------------------------------------------
-------------- Fin Fonctions ---------------
-------------------------------------------- 

voir_les_logs("========= ".. nom_script .." (v".. version ..") =========",debugging)
-- calcul DJU
if otherdevices_svalues[temp_ext] ~= nil then
    if (uservariables[var_user_dju] == nil) then creaVar(var_user_dju,2,0)end
    temperature = tonumber(string.match(otherdevices_svalues[temp_ext], "%d+%.*%d*"))
    if temperature < 18 then
        voir_les_logs("--- --- Température extérieure : ".. temperature .."°C inférieure à 18°C --- ---",debugging)
        dju = calc_dju(temperature)
        voir_les_logs("--- --- DJU : ".. dju .." --- ---",debugging)
        voir_les_logs("--- --- Variable DJU : ".. uservariables[var_user_dju] .." --- ---",debugging)
        somme_dju = tonumber(uservariables[var_user_dju]) + dju
        voir_les_logs("--- --- somme DJU : ".. somme_dju .." --- ---",debugging)
        commandArray[#commandArray+1] = {['Variable:'.. var_user_dju] = tostring(somme_dju)}
    else
        voir_les_logs("--- --- Température extérieure : ".. temperature .."°C  supérieure à 18°C --- ---",debugging)
        somme_dju = tonumber(uservariables[var_user_dju])
        voir_les_logs("--- --- somme DJU : ".. somme_dju .." --- ---",debugging)
        
    end
    if time.hour == heure_raz_var and time.min == minute_raz_var then 
        voir_les_logs("--- --- incrémentation compteur DJU et remise à zéro variable utilisateur ".. var_user_dju .."  --- ---",debugging)
        if compteur_dju_idx ~= nil then
            commandArray[#commandArray+1] = {['UpdateDevice'] = compteur_dju_idx .. '|0|' .. round(somme_dju,1)}
        end
        commandArray[#commandArray+1] = {['Variable:'.. var_user_dju] = tostring(0)}	
    end    
else
    voir_les_logs("--- --- le device : ".. temp_ext .." n\'existe pas --- ---",debugging)
end
-- fin calcul DJU
-- calcul nrj consommée
if otherdevices_svalues[cpt_gaz] ~= nil then
    if (uservariables[var_user_gaz] == nil) then creaVar(var_user_gaz,2,0)end
    voir_les_logs("--- --- Compteur gaz : ".. otherdevices_svalues[cpt_gaz]/100 .." m3 --- ---",debugging) -- /100 car compteur gaz en décalitres 1 impulsion tous les 0.01 m3
    voir_les_logs("--- --- Précédent index gaz : ".. uservariables[var_user_gaz]/100 .." m3 --- ---",debugging)-- /100 car compteur gaz en décalitres 1 impulsion tous les 0.01 m3
    conso_gaz = tonumber(otherdevices_svalues[cpt_gaz]/100) - tonumber(uservariables[var_user_gaz]/100) -- /100 car compteur gaz en décalitres  impulsion tous les 0.01 m3
    voir_les_logs("--- --- Consommation gaz : ".. conso_gaz .." m3 --- ---",debugging)
    conso_nrj = conso_gaz * coef_gaz * 1000  -- transformation en Wh
    voir_les_logs("--- --- Coeff conversion gaz : ".. coef_gaz .." --- ---",debugging)   
    voir_les_logs("--- --- Consommation nrj : ".. conso_nrj .." Wh--- ---",debugging)
    --if cpt_nrj_idx ~= nil then
    if compteur_nrj ~= nil then
      cpt_nrj = GetDeviceNameByIDX(cpt_nrj_idx)
      index_nrj = otherdevices_svalues[cpt_nrj]
      voir_les_logs("--- --- Compteur nrj : ".. index_nrj .." Wh --- ---",debugging)
      conso_nrj = tonumber(index_nrj) + tonumber(conso_nrj) 
      -- commandArray[#commandArray+1] = {['UpdateDevice'] = cpt_nrj_idx .. '|0|' .. round(conso_nrj,2)}
      commandArray[#commandArray+1] = {['UpdateDevice'] = GetDeviceIdxByName(compteur_nrj) .. '|0|' .. round(conso_nrj,2)}
    end
    commandArray[#commandArray+1] = {['Variable:'.. var_user_gaz] = tostring(otherdevices_svalues[cpt_gaz])}
end
voir_les_logs("========= Fin ".. nom_script .." (v".. version ..") =========",debugging)

return commandArray

