--[[
  Nya, single-file Lua file that implements Roblox-like APIs
  Copyright (C) 2026 Kindtracker

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local Nya = {}

local Instance = {}

Instance.Classes = {}

function Instance:RegisterClass(Name, Module, ParentModule)
  self.Classes[Name] = {
    Module = Module,
    ParentModule = ParentModule,
  }
end

function Instance:RemoveClass(Name)
  self.Classes[Name] = nil
end

function Instance:FindClassByName(Name)
  return self.Classes[Name]
end

function Instance.new(ClassName, Parent)
  ClassName = ClassName or "Instance"

  local Properties = {
    Name = ClassName,
    ClassName = ClassName,
    Parent = nil,
    Children = {},
    Attributes = {},
    Tags = {},
    UniqueId = tostring({}):gsub("table: ", ""),
    Changed = Signal.new(),
    ChildAdded = Signal.new(),
    ChildRemoved = Signal.new(),
    Destroying = Signal.new(),
    AncestryChanged = Signal.new(),
    DescendantAdded = Signal.new(),
    DescendantRemoving = Signal.new(),
  }

  local Methods = {}
  local PropertySignals = {}
  local self = {}

  local function FindChild(Name)
    for _, Child in pairs(Properties.Children) do
      if Child.Name == Name then
        return Child
      end
    end
  end

  local function LoadClass(Name)
    local Class = Instance.Classes[Name]
    if not Class then
      return
    end

    if type(Class.ParentModule) == "string" then
      LoadClass(Class.ParentModule)
    elseif type(Class.ParentModule) == "table" then
      for Key, Value in pairs(Class.ParentModule.new()) do
        Properties[Key] = Value
      end
    end

    if Class.Module and Class.Module.new then
      for Key, Value in pairs(Class.Module.new()) do
        Properties[Key] = Value
      end
    end
  end

  local function RemoveChild(Child)
    Properties.Children[Child.UniqueId] = nil
    Properties.ChildRemoved:Fire(Child)
    Properties.DescendantRemoving:Fire(Child)
  end

  local function AddChild(Child)
    Properties.Children[Child.UniqueId] = Child
    Properties.ChildAdded:Fire(Child)
    Properties.DescendantAdded:Fire(Child)
  end

  setmetatable(self, {
    __index = function(_, Key)
      if Properties[Key] ~= nil then
        return Properties[Key]
      end

      if Methods[Key] then
        return Methods[Key]
      end

      if PropertySignals[Key] then
        return PropertySignals[Key]
      end

      -- Instance.ChildName
      return FindChild(Key)
    end,

    __newindex = function(_, Key, Value)
      local OldValue = Properties[Key]

      if Key == "Parent" then
        if OldValue == Value then
          return
        end

        if OldValue then
          RemoveChild(self)
        end

        Properties.Parent = Value

        if Value then
          AddChild(self)
          Properties.AncestryChanged:Fire(self, Value)
        end
      else
        Properties[Key] = Value
      end

      if PropertySignals[Key] then
        PropertySignals[Key]:Fire(Value, OldValue)
        Properties.Changed:Fire(Key, Value, OldValue)
      end
    end,

    __len = function()
      return #Properties.Children
    end,

    __pairs = function()
      return next, Properties, nil
    end,
  })

  LoadClass(ClassName)

  function Methods:GetChildren()
    return Properties.Children
  end

  function Methods:GetChildrenCount()
    local Count = 0
    for _ in pairs(Properties.Children) do
      Count = Count + 1
    end
    return Count
  end

  function Methods:AddChild(Child)
    Child.Parent = self
  end

  function Methods:FindFirstChild(Name, Recursive)
    local Child = FindChild(Name)
    if Child or not Recursive then
      return Child
    end

    for _, Item in pairs(Properties.Children) do
      Child = Item:FindFirstChild(Name, true)
      if Child then
        return Child
      end
    end
  end

  function Methods:FindFirstChildOfClass(Name, Recursive)
    for _, Child in pairs(Properties.Children) do
      if Child.ClassName == Name then
        return Child
      end

      if Recursive then
        local Found = Child:FindFirstChildOfClass(Name, true)
        if Found then
          return Found
        end
      end
    end
  end

  function Methods:FindFirstChildWhichIsA(Name, Recursive)
    for _, Child in pairs(Properties.Children) do
      if Child:IsA(Name) then
        return Child
      end

      if Recursive then
        local Found = Child:FindFirstChildWhichIsA(Name, true)
        if Found then
          return Found
        end
      end
    end
  end

  function Methods:FindFirstDescendant(Name)
    return self:FindFirstChild(Name, true)
  end

  function Methods:GetDescendants()
    local Result = {}

    local function Add(Parent)
      for _, Child in pairs(Parent:GetChildren()) do
        table.insert(Result, Child)
        Add(Child)
      end
    end

    Add(self)
    return Result
  end

  function Methods:GetPropertyChangedSignal(Name)
    PropertySignals[Name] = PropertySignals[Name] or Signal.new()
    return PropertySignals[Name]
  end

  function Methods:SetAttribute(Name, Value)
    local OldValue = Properties.Attributes[Name]
    Properties.Attributes[Name] = Value

    if Properties.AttributeSignals and Properties.AttributeSignals[Name] then
      Properties.AttributeSignals[Name]:Fire(Value, OldValue)
    end
  end

  function Methods:GetAttribute(Name)
    return Properties.Attributes[Name]
  end

  function Methods:GetAttributes()
    return Properties.Attributes
  end

  function Methods:GetAttributeChangedSignal(Name)
    Properties.AttributeSignals = Properties.AttributeSignals or {}
    Properties.AttributeSignals[Name] = Properties.AttributeSignals[Name] or Signal.new()

    return Properties.AttributeSignals[Name]
  end

  function Methods:RemoveAttribute(Name)
    Properties.Attributes[Name] = nil
  end

  function Methods:AddTag(Name)
    Properties.Tags[Name] = true
  end

  function Methods:RemoveTag(Name)
    Properties.Tags[Name] = nil
  end

  function Methods:HasTag(Name)
    return Properties.Tags[Name] == true
  end

  function Methods:GetTags()
    local Result = {}
    for Name in pairs(Properties.Tags) do
      table.insert(Result, Name)
    end
    return Result
  end

  function Methods:IsA(Name)
    local Current = Properties.ClassName

    while Current do
      if Current == Name then
        return true
      end

      local Class = Instance.Classes[Current]
      Current = Class and Class.ParentModule
    end

    return false
  end

  function Methods:GetFullName()
    local Result = Properties.Name
    local Parent = Properties.Parent

    while Parent do
      Result = Parent.Name .. "." .. Result
      Parent = Parent.Parent
    end

    return Result
  end

  function Methods:FindFirstAncestor(Name)
    local Parent = Properties.Parent

    while Parent do
      if Parent.Name == Name then
        return Parent
      end
      Parent = Parent.Parent
    end
  end

  function Methods:FindFirstAncestorOfClass(Name)
    local Parent = Properties.Parent

    while Parent do
      if Parent.ClassName == Name then
        return Parent
      end
      Parent = Parent.Parent
    end
  end

  function Methods:FindFirstAncestorWhichIsA(Name)
    local Parent = Properties.Parent

    while Parent do
      if Parent:IsA(Name) then
        return Parent
      end
      Parent = Parent.Parent
    end
  end

  function Methods:IsAncestorOf(Descendant)
    local Parent = Descendant.Parent

    while Parent do
      if Parent == self then
        return true
      end
      Parent = Parent.Parent
    end

    return false
  end

  function Methods:IsDescendantOf(Ancestor)
    return Ancestor:IsAncestorOf(self)
  end

  function Methods:ClearAllChildren()
    for _, Child in pairs(Properties.Children) do
      Child:Destroy()
    end
  end

  function Methods:Destroy(Recursive)
    Properties.Destroying:Fire()

    local Parent = Properties.Parent
    if Parent then
      self.Parent = nil
    end

    for _, Child in pairs(Properties.Children) do
      if Recursive == false then
        Child.Parent = Parent
      else
        Child:Destroy()
      end
    end

    Properties.Children = {}
  end

  function Methods:Clone()
    local Copy = Instance.new(Properties.ClassName)
    for Key, Value in pairs(Properties) do
      if
        Key ~= "Children"
        and Key ~= "Parent"
        and Key ~= "Changed"
        and Key ~= "ChildAdded"
        and Key ~= "ChildRemoved"
        and Key ~= "Destroying"
        and Key ~= "AncestryChanged"
        and Key ~= "DescendantAdded"
        and Key ~= "DescendantRemoving"
      then
        Copy[Key] = type(Value) == "table" and table.clone and table.clone(Value) or Value
      end
    end

    for _, Child in pairs(Properties.Children) do
      Copy:AddChild(Child:Clone())
    end

    return Copy
  end

  Properties.Name = ClassName

  if Parent then
    self.Parent = Parent
  end

  return self
end

local ServiceManager = {}

ServiceManager.Services = {}

function ServiceManager:RegisterService(ServiceName, Service)
  self.Services[ServiceName] = Service
  return Service
end

function ServiceManager:GetService(ServiceName)
  return self.Services[ServiceName]
end

function ServiceManager:FindService(ServiceName)
  return self.Services[ServiceName]
end

function ServiceManager:HasService(ServiceName)
  return self.Services[ServiceName] ~= nil
end

function ServiceManager:RemoveService(ServiceName)
  local Service = self.Services[ServiceName]
  self.Services[ServiceName] = nil
  return Service
end

local Connection = {}

function Connection.new(Callback, DisconnectCallback)
  return {
    Connected = Callback ~= nil,
    Callback = Callback,

    Disconnect = function(self)
      if not self.Connected then
        return
      end
      self.Connected = false

      if DisconnectCallback then
        DisconnectCallback()
      end
    end,
  }
end

local Signal = {}

function Signal.new()
  local self = { Connections = {} }

  function self:Connect(Callback, DisconnectCallback)
    local ConnectionObject

    ConnectionObject = Connection.new(Callback, function()
      for i, Item in ipairs(self.Connections) do
        if Item == ConnectionObject then
          table.remove(self.Connections, i)
          break
        end
      end

      if DisconnectCallback then
        DisconnectCallback(ConnectionObject)
      end
    end)

    table.insert(self.Connections, ConnectionObject)
    return ConnectionObject
  end

  function self:DisconnectAll()
    while #self.Connections > 0 do
      self.Connections[1]:Disconnect()
    end
  end

  function self:Fire(...)
    for _, Item in ipairs(self.Connections) do
      if Item.Connected then
        Item.Callback(...)
      end
    end
  end

  return self
end

local Color3 = {}
local Color3Meta = {}
Color3Meta.__index = Color3Meta

function Color3.new(R, G, B)
  return setmetatable({
    R = R or 0,
    G = G or 0,
    B = B or 0,
  }, Meta)
end

function Color3.fromRGB(R, G, B)
  return Color3.new(R / 255, G / 255, B / 255)
end

function Color3.fromHex(Hex)
  Hex = Hex:gsub("#", "")
  if #Hex == 3 then
    Hex = Hex:sub(1, 1):rep(2) .. Hex:sub(2, 2):rep(2) .. Hex:sub(3, 3):rep(2)
  end

  return Color3.fromRGB(tonumber(Hex:sub(1, 2), 16), tonumber(Hex:sub(3, 4), 16), tonumber(Hex:sub(5, 6), 16))
end

function Color3.fromHSV(H, S, V)
  H = (H % 1) * 6
  local C = V * S
  local X = C * (1 - math.abs(H % 2 - 1))
  local M = V - C
  local R, G, B

  if H < 1 then
    R, G, B = C, X, 0
  elseif H < 2 then
    R, G, B = X, C, 0
  elseif H < 3 then
    R, G, B = 0, C, X
  elseif H < 4 then
    R, G, B = 0, X, C
  elseif H < 5 then
    R, G, B = X, 0, C
  else
    R, G, B = C, 0, X
  end

  return Color3.new(R + M, G + M, B + M)
end

function Color3Meta:ToHSV()
  local R, G, B = self.R, self.G, self.B
  local Max, Min = math.max(R, G, B), math.min(R, G, B)
  local D, H = Max - Min, 0

  if D ~= 0 then
    if Max == R then
      H = ((G - B) / D) % 6
    elseif Max == G then
      H = (B - R) / D + 2
    else
      H = (R - G) / D + 4
    end
    H = H / 6
  end

  return H, Max == 0 and 0 or D / Max, Max
end

function Color3Meta:ToHex()
  return string.format("#%02X%02X%02X", math.floor(self.R * 255), math.floor(self.G * 255), math.floor(self.B * 255))
end

function Color3Meta:Lerp(Goal, Alpha)
  return Color3.new(
    self.R + (Goal.R - self.R) * Alpha,
    self.G + (Goal.G - self.G) * Alpha,
    self.B + (Goal.B - self.B) * Alpha
  )
end

function Color3Meta:__tostring()
  return string.format("Color3(%.3f, %.3f, %.3f)", self.R, self.G, self.B)
end

local Color4 = {}
local Color4Meta = {}
Color4Meta.__index = Color4Meta

function Color4.new(R, G, B, A)
  return setmetatable({
    R = R or 0,
    G = G or 0,
    B = B or 0,
    A = A == nil and 1 or A,
  }, Color4Meta)
end

function Color4.fromRGB(R, G, B)
  return Color4.new(R / 255, G / 255, B / 255)
end

function Color4.fromRGBA(R, G, B, A)
  return Color4.new(R / 255, G / 255, B / 255, A / 255)
end

function Color4.fromHSV(H, S, V)
  return Color4.fromHSVA(H, S, V, 255)
end

function Color4.fromHSVA(H, S, V, A)
  H, S, V = H % 1 * 6, math.clamp(S, 0, 1), math.clamp(V, 0, 1)

  local C = V * S
  local X = C * (1 - math.abs(H % 2 - 1))
  local M = V - C
  local R, G, B

  if H < 1 then
    R, G, B = C, X, 0
  elseif H < 2 then
    R, G, B = X, C, 0
  elseif H < 3 then
    R, G, B = 0, C, X
  elseif H < 4 then
    R, G, B = 0, X, C
  elseif H < 5 then
    R, G, B = X, 0, C
  else
    R, G, B = C, 0, X
  end

  return Color4.new(R + M, G + M, B + M, (A or 255) / 255)
end

function Color4.fromHex(Hex)
  Hex = Hex:gsub("#", "")

  if #Hex == 3 or #Hex == 4 then
    Hex = Hex:gsub(".", function(C)
      return C .. C
    end)
  end

  local R = tonumber(Hex:sub(1, 2), 16)
  local G = tonumber(Hex:sub(3, 4), 16)
  local B = tonumber(Hex:sub(5, 6), 16)
  local A = #Hex == 8 and tonumber(Hex:sub(7, 8), 16) or 255

  return Color4.fromRGBA(R, G, B, A)
end

function Color4Meta:ToHSV()
  local R, G, B = self.R, self.G, self.B
  local Max, Min = math.max(R, G, B), math.min(R, G, B)
  local D, H = Max - Min, 0

  if D ~= 0 then
    if Max == R then
      H = ((G - B) / D) % 6
    elseif Max == G then
      H = (B - R) / D + 2
    else
      H = (R - G) / D + 4
    end
    H = H / 6
  end

  return H, Max == 0 and 0 or D / Max, Max
end

function Color4Meta:ToHSVA()
  local H, S, V = self:ToHSV()
  return H, S, V, self.A
end

function Color4Meta:ToHex()
  return string.format(
    "#%02X%02X%02X%02X",
    math.floor(self.R * 255),
    math.floor(self.G * 255),
    math.floor(self.B * 255),
    math.floor(self.A * 255)
  )
end

function Color4Meta:Lerp(Goal, Alpha)
  return Color4.new(
    self.R + (Goal.R - self.R) * Alpha,
    self.G + (Goal.G - self.G) * Alpha,
    self.B + (Goal.B - self.B) * Alpha,
    self.A + (Goal.A - self.A) * Alpha
  )
end

function Color4Meta:__tostring()
  return string.format("Color4(%.3f, %.3f, %.3f, %.3f)", self.R, self.G, self.B, self.A)
end

Nya.Instance = Instance
Nya.ServiceManager = ServiceManager
Nya.Connection = Connection
Nya.Signal = Signal
Nya.Color3 = Color3
Nya.Color4 = Color4

for Key, Value in pairs(ServiceManager) do
  Nya[Key] = Value
end

return Nya
