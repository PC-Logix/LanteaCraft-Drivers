local component = require("component")
local fs = require("filesystem")
local internet = require("internet")
local process = require("process")
local event = require("event")
local keyboard = require("keyboard")
local shell = require("shell")
local term = require("term")
local text = require("text")
local unicode = require("unicode")
local sides = require("sides")
local colors=require("colors")
local gml=require("gml")

local sg = component.stargate
local gpu=component.gpu
local w, h = gpu.getResolution()
local fname = "GateInfo.txt"
local filename = shell.resolve(fname)
local connectAddress = ""
local destAddress = {}
local destName = {}
local timerID = 0
local fuelTimer = 0
local running=process.running() 
local addressListAdd
local addressListDelete

local function isAdvanced()
	return gpu.getDepth()
end

local function strripos(s, delim)
	return s:match('^.*()'..delim)
end

function loadAddressData()
  destName = {}
  destAddress = {}
	do
		local f = io.open(filename)
		if f then
			for line in f:lines() do
				line = text.trim(line)
				delimPos = strripos(line, ",")
				table.insert(destName, string.sub(line, 1, delimPos - 1))
				table.insert(destAddress, string.sub(line, delimPos + 1, string.len(line)))
			end
			f:close()
		end
	end
  if (#destName < 1) then
    destName = {" "}
    destAddress = {" "}
  end
end

term.clear()
local gui=gml.create("center", "center", 80, 25)
gui.style=gml.loadStyle("cv.gss")

local function dialing()
  return tostring(sg.isDialing())
end

local function connected()
  return tostring(sg.isConnected())
end

local function fuelAvailable()
  return tostring(sg.hasFuel())
end

local function valid(address)
  return "true"
end
 
loadAddressData()

local addressListBoxGUI = gml.create("center", 18, 48, 16)
local addressList=gui:addListBox(21, 7, 38, 8, destName)
local addressLabel=gui:addLabel(19, 16, 41,"Destination:  "..text.trim(destAddress[1]))
local validLabel=gui:addLabel(19, 18, 41, "Valid:  "..valid(text.trim(destAddress[1])))     

local contentsLabel=gui:addLabel(5, 2, 15, "Gate Address:")
local contentsActiveLabel=gui:addLabel(20, 2, 9, "         ")
contentsActiveLabel.text = text.trim(sg.getAddress())
contentsActiveLabel["text-color"] = 0xFFFFFF
contentsActiveLabel["text-background"] = 0x0000AA
contentsActiveLabel:draw()

local fuelLabel=gui:addLabel(35, 2, 30, "Has Fuel:")
local fuelLabelActive=gui:addLabel(48, 2, 7, "looking")

local dialingLabel=gui:addLabel(5, 4, 13,"Dialing:  ")
local dialingActiveLabel=gui:addLabel(20, 4, 7,"       ")
local connectedLabel=gui:addLabel(35, 4, 17, "Connected:  ")
local connectedActiveLabel=gui:addLabel(48, 4, 7, "       ")

local function hasFuel()
  if (text.trim(fuelAvailable()) == "false") then
    fuelLabelActive["text-color"] = 0xFFFFFF
    fuelLabelActive["text-background"] = 0xBB0000
  else
    fuelLabelActive["text-color"] = 0xFFFFFF
    fuelLabelActive["text-background"] = 0x009900
  end
  fuelLabelActive.text = fuelAvailable()
  fuelLabelActive:draw()
end

function saveAddressData()
	do
		local f = io.open(filename, "w")
		if f then
			for a = 1, #destName do
        f:write(tostring(destName[a])..","..string.sub(tostring(destAddress[a]), 1, 9).."\n")
			end
			f:close()
		end
	end
  addressList:updateList(destName)
end

local function cancelAddress()
  newAddressField.text = ""
  newGateAddressField.text = ""
  newAddressField:draw()
  newGateAddressField:draw()
end

local function deleteAddress()
  for id, name in pairs(destName) do
    if text.trim(name) == text.trim(addressList:getSelected()) then
      addressID = id
      break
    end
  end
  if addressID ~= 0 then
    table.remove(destName, addressID)
    table.remove(destAddress, addressID)
  end
  addressList:updateList(destName)
  saveAddressData()
end

local function setNewAddressData()
  if (string.len(text.trim(newAddressField.text)) > 1) then
    destName[#destName + 1] = text.trim(newAddressField.text)
    destAddress[#destAddress + 1] = text.trim(newGateAddressField.text)
    newAddressField.text = ""
    newGateAddressField.text = ""
    newAddressField:draw()
    newGateAddressField:draw()
  end
  saveAddressData()
end

local function addAddress()
  gpu.setForeground(0xFFFFFF)
  gpu.setBackground(0x000000)
  term.clear()
  newAddressGUI = gml.create("center", "center", 50, 16)
  newAddressLabel=newAddressGUI:addLabel(2, 2, 13,"Address Name:")
  newAddressField=newAddressGUI:addTextField(15, 2, 30)
  newGateAddressLabel=newAddressGUI:addLabel(2, 4, 13,"Gate Address:")
  newGateAddressField=newAddressGUI:addTextField(15, 4, 10)
  newAddressSave=newAddressGUI:addButton(5, 6, 10, 1, "Save", setNewAddressData)
  newAddressCancel=newAddressGUI:addButton(20, 6, 10, 1, "Cancel", cancelAddress)
  newAddressClose=newAddressGUI:addButton(35, 6, 10, 1, "Close", newAddressGUI.close)
  newAddressGUI:run()
  term.clear()
  gui:draw()
  addressListBoxGUI:draw()
  addressList:draw()
  addressLabel:draw()
  addressListAdd:draw()
  addressListDelete:draw()
  validLabel:draw()
  dialingLabel:draw()
  dialingActiveLabel:draw()
end

addressListAdd=gui:addButton(25, 20, 10, 1, "Add", addAddress)
addressListDelete=gui:addButton(45, 20, 10, 1, "Delete", deleteAddress)

gui.onClose=function()
  event.cancel(fuelTimer)
end

gui.onRun=function()
  fuelID = event.timer(20, hasFuel, math.huge)
  addressListBoxGUI:draw()
  addressList:draw()
  addressLabel:draw()
  addressListAdd:draw()
  addressListDelete:draw()
  validLabel:draw()
  dialingLabel:draw()
  dialingActiveLabel:draw()
end

local function updateValues()
  event.cancel(timerID)
  connectedActiveLabel.text=string.sub(" "..connected().."  ", 1, 7)
  dialingActiveLabel.text= string.sub(" "..dialing().."  ", 1, 7)

  if (text.trim(connected()) == "false") then
    connectedActiveLabel["text-color"] = 0xFFFFFF
    connectedActiveLabel["text-background"] = 0xBB0000
  else
    connectedActiveLabel["text-color"] = 0xFFFFFF
    connectedActiveLabel["text-background"] = 0x009900
  end
  if (text.trim(dialing()) == "false") then
    dialingActiveLabel["text-color"] = 0xFFFFFF
    dialingActiveLabel["text-background"] = 0xBB0000
  else
    dialingActiveLabel["text-color"] = 0xFFFFFF
    dialingActiveLabel["text-background"] = 0x009900
  end

  connectedLabel:draw()
  connectedActiveLabel:draw()
  dialingLabel:draw()
  dialingActiveLabel:draw()
end

local function updateDialAddress(info)
  local addressID = 0
  local addInfo = text.trim(info)
  connectAddress = ""
  
  for id, name in pairs(destName) do
    if text.trim(name) == text.trim(addInfo) then
      addressID = id
      break
    end
  end
  if addressID ~= 0 then
    connectAddress = text.trim(destAddress[addressID])
    addressLabel.text="Address: "..destAddress[addressID]
    addressLabel:draw()
  end
  validLabel.text= "Valid:  "..valid(connectAddress)
  validLabel:draw()
end

local function disconnect()
  sg.disconnect()
  os.sleep(2)
  updateValues()
end

local function dialGate()
  if (valid(connectAddress) == "true") then
    sg.dial(connectAddress)
    dialingActiveLabel["text-color"] = 0xFFFFFF
    dialingActiveLabel["text-background"] = 0x009900
    dialingActiveLabel.text= string.sub(" "..dialing().."  ", 1, 7)
    dialingActiveLabel:draw()
    timerID = event.timer(26, updateValues, 1)
  end
end

local function onAddressDial()
  updateDialAddress(addressList:getSelected())
  dialGate()
end

local connect=gui:addButton(15,-1,10,1,"Connect",onAddressDial)
local disconnect=gui:addButton(35,-1,10,1,"Disconnect", disconnect)
local close=gui:addButton(55,-1,10,1,"Close",gui.close)

local function onAddressSelect(lb,prevIndex,selIndex)
  updateDialAddress(addressList:getSelected())
end

addressList.onChange=onAddressSelect

addressList.onDoubleClick=function()
  updateDialAddress(addressList:getSelected())
end

updateValues()
gui:run()

gpu.setForeground(0xFFFFFF)
gpu.setBackground(0x000000)
term.clear()
