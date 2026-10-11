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

local function NewSignal()
  local Signal = { Connections = {} }

  function Signal:Connect(Callback)
    local Connection = { Connected = true }

    function Connection:Disconnect()
      self.Connected = false
    end

    Connection.Callback = Callback
    table.insert(Signal.Connections, Connection)
    return Connection
  end

  function Signal:Fire(...)
    for _, Connection in ipairs(Signal.Connections) do
      if Connection.Connected then
        Connection.Callback(...)
      end
    end
  end

  function Signal:DisconnectAll()
    for _, Connection in ipairs(self.Connections) do
      Connection:Disconnect()
    end
    self.Connections = {}
  end

  return Signal
end

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
    Changed = NewSignal(),
    ChildAdded = NewSignal(),
    ChildRemoved = NewSignal(),
    Destroying = NewSignal(),
    AncestryChanged = NewSignal(),
    DescendantAdded = NewSignal(),
    DescendantRemoving = NewSignal(),
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
    PropertySignals[Name] = PropertySignals[Name] or NewSignal()
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
    Properties.AttributeSignals[Name] = Properties.AttributeSignals[Name] or NewSignal()

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

Nya.Instance = Instance
Nya.ServiceManager = ServiceManager

for Key, Value in pairs(ServiceManager) do
  Nya[Key] = Value
end

return Nya
