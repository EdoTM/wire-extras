
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

ENT.WireDebugName = "WIRE_FieldGen"

local EMP_IGNORE_INPUTS = { Kill = true , Pod = true , Eject = true , Lock = true , Terminate = true }
EMP_IGNORE_INPUTS["Damage Armor"] = true
EMP_IGNORE_INPUTS["Strip weapons"] = true
EMP_IGNORE_INPUTS["Damage Health"] = true

function ENT:Initialize()
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    self.multiplier = 1
    self.active = false
    self.objects = {}
    self.range = 100
    self.direction = Vector(0,1,0)
    self.ignore = {}

    self.props = 1
    self.npcs = 1
    self.player = 0

    if (self.FieldType == "Wind") then
        self.direction = Vector(1,0,0)
    end

    self:ConfigInOuts()
    self:SetOverlayText(self:GetDisplayText())

end

function ENT:SetType(v)
    self.FieldType = v
end

function ENT:Setworkonplayers(v)
    self.workonplayers = v != 0
end

function ENT:Setignoreself(v)
    self.ignoreself = v
end

function ENT:Setarc(v)
    self.arc = v
end


function ENT:BuildIgnoreList()

    local queue = {self}
    self.ignore = {}
    self.ignore[ self:EntIndex() ] = self

    while !table.IsEmpty(queue) do

        local constraints = constraint.GetTable(table.remove(queue))
        if !constraints then return end

        for _, constr in pairs(constraints) do
            Msg("\n\n======== Constraint: ========")
            PrintTable(constr)
            Msg("\n")
            if constr.Constraint.Type == "Rope" then continue end
            for _, connected_ent_info in pairs(constr.Entity) do
                if self.ignore[ connected_ent_info.Index ] == connected_ent_info.Entity then continue end
                self.ignore[ connected_ent_info.Index ] = connected_ent_info.Entity
                table.insert(queue, connected_ent_info.Entity)
            end
        end
    end
end


function ENT:GetTypes()
    return {
        "Gravity",
        "Pull",
        "Push",
        "Hold",
        "Wind",
        "Vortex",
        "Flame",
        "Crush",
        "EMP",
        "Death",
        "Heal",
        "Battery",
        "NoCollide",
        "Speed"
    }
end

local TypeNames = {
    ["Gravity"] = "Zero Gravity",
    ["Pull"] = "Attraction",
    ["Push"] = "Repulsion",
    ["Hold"] = "Stasis",
    ["Wind"] = "Wind",
    ["Vortex"] = "Vortex",
    ["Flame"] = "Flame",
    ["Crush"] = "Pressure",
    ["EMP"] = "Electromagnetic",
    ["Death"] = "Radiation",
    ["Heal"] = "Recovery",
    ["Battery"] = "Battery",
    ["NoCollide"] = "Phase",
    ["Speed"] = "Accelerator"
}

function ENT:GetTypeName(Type)
    return TypeNames[Type] or ""
end

function ENT:GetDisplayText()

    local Text = self:GetTypeName(self.FieldType) .. " Field Generator ("

    if !self.active then
        Text = Text .. "Off)"
    else
        Text = Text .. "On)"
    end

    return Text

end


local default_inputs = { "Active", "Range", "Multiplier" }
local gravity_inputs = { "Active", "Range" }
local wind_and_vortex_inputs = {
    "Active",
    "Range",
    "Multiplier",
    "Direction.X" ,
    "Direction.Y",
    "Direction.Z",
    "Direction" }


function ENT:ConfigInOuts()

    if self.FieldType == "Gravity" then
        self.Inputs = Wire_CreateInputs(self, gravity_inputs)
    elseif self.FieldType == "Wind" or self.FieldType == "Vortex" then
        self.Inputs = Wire_CreateInputs(self, wind_and_vortex_inputs)
        WireLib.AdjustSpecialInputs(self, wind_and_vortex_inputs, {"NORMAL","NORMAL","NORMAL","NORMAL","NORMAL","NORMAL", "VECTOR"})
    else
        self.Inputs = Wire_CreateInputs(self, default_inputs)
    end

    self.Outputs = Wire_CreateOutputs(self, { })

end

function ENT:TriggerInput(iname, value)

    if value != nil then
        if iname == "Range" then
            self.range = value

        elseif iname == "Direction.X" then
            self.direction.x = value

        elseif iname == "Direction.Y" then
            self.direction.y = value

        elseif iname == "Direction.Z" then
            self.direction.z = value

        elseif iname == "Direction" then
            if isvector(value) then Msg("non vector passed!\n") return end
            self.direction = value

        elseif iname == "Multiplier" then
            if value > 0 then
                self.multiplier = value
            else
                self.multiplier = 1.0
            end

        elseif iname == "Active" then
            self.active = value != 0
        end
    end

    if !self.active then
        self:Disable()
    end
    self:SetOverlayText(self:GetDisplayText())

end


function IsTrue(value)

    if  isnumber(value) and math.abs(value) < 0.0001
        or isstring(value) and value == "0" then
            return false
    end

    return value
end

function IsFalse(value)
    return !IsTrue(value)
end

function ENT:EnableEntityGravity(obj)
    if obj:IsPlayer() then
        obj:SetMoveType(MOVETYPE_WALK)
        obj:SetMoveCollide(MOVECOLLIDE_DEFAULT)
    elseif obj:IsNPC() then
        obj:SetMoveType(MOVETYPE_STEP)
        obj:SetMoveCollide(MOVECOLLIDE_DEFAULT)
    else
        obj:SetGravity(1)
    end
end


function ENT:DisableEntityGravity(obj)
    if obj:IsPlayer() or obj:IsNPC() then
        obj:SetMoveType(MOVETYPE_FLY)
        obj:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
    else
        obj:SetGravity(0)
    end
end


function ENT:Toggle_Prop_Gravity(obj, active)

    local obj_movetype = obj:GetMoveType()

    if	obj_movetype == MOVETYPE_NONE
        or obj_movetype == MOVETYPE_NOCLIP then return false end

    if obj_movetype != MOVETYPE_VPHYSICS then
        if active then
            self:EnableEntityGravity(obj)
        else
            self:DisableEntityGravity(obj)
        end
    end

    if obj:GetPhysicsObjectCount() > 1 then
        for x = 0, obj:GetPhysicsObjectCount() - 1 do
            local part = obj:GetPhysicsObjectNum(x)
            part:EnableGravity(active)
        end
        return false
    end

    local phys = obj:GetPhysicsObject()

    if phys:IsValid() then
        phys:EnableGravity(active)
    end

end


function ENT:Gravity_Logic()

    local NewObjs = {}

    for _, contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do
        self:Toggle_Prop_Gravity(contact , false)
        NewObjs[ contact:EntIndex() ] = contact
    end

    for index, contact in pairs(self.objects) do
        if (NewObjs[ index ] != contact) then
            self:Toggle_Prop_Gravity(contact , true)
        end
    end

    self.objects = NewObjs

end

function ENT:Gravity_Disable()

    for _,contact in pairs(self.objects) do
        self:Toggle_Prop_Gravity(contact, true)
    end

end

function ENT:Slow_Prop(prop , yes_no)

    if prop:GetMoveType() == MOVETYPE_NONE then return false end

    if prop:GetMoveType() != MOVETYPE_VPHYSICS then
        if yes_no == false then

            if prop:IsNPC() or prop:IsPlayer() then

                if !prop:Alive() and prop:GetRagdollEntity() then
                    local RagDoll = prop:GetRagdollEntity()
                    for x = 1,RagDoll:GetPhysicsObjectCount() do
                        local part = RagDoll:GetPhysicsObjectNum(x)

                        part:EnableGravity(yes_no)
                        part:SetDragCoefficient(100 * self.multiplier)

                    end
                end

                prop:SetMoveType(MOVETYPE_FLY)
                prop:SetMoveCollide(MOVECOLLIDE_FLY_BOUNCE)
            else
                prop:SetGravity(0)
            end

            local adjusted_multiplier = math.max(self.multiplier + 15.1, 15.1)
            local Mul = 15 / adjusted_multiplier - 1
            local vel = prop:GetVelocity()

            if prop.AddVelocity then
                prop:AddVelocity(vel * Mul)
            else
                prop:SetVelocity(vel * Mul)
            end

        else


            if prop:IsNPC() or prop:IsPlayer() or !prop:Alive() and prop:GetRagdollEntity() then
                local RagDoll = prop:GetRagdollEntity()
                for x = 1,RagDoll:GetPhysicsObjectCount() do
                    local part = RagDoll:GetPhysicsObjectNum(x)

                    part:EnableGravity(yes_no)
                    part:SetDragCoefficient(1)

                end
            end


            if prop:IsPlayer() then
                prop:SetMoveCollide(MOVETYPE_WALK)
                prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
            elseif prop:IsNPC() then
                prop:SetMoveCollide(MOVETYPE_STEP)
                prop:SetMoveCollide(MOVECOLLIDE_DEFAULT)
            else
                prop:SetGravity(1)
            end

        end
    end

    if prop:GetPhysicsObjectCount() > 1 then
        for x = 0, prop:GetPhysicsObjectCount() - 1 do
            local part = prop:GetPhysicsObjectNum(x)

            part:EnableGravity(yes_no)
            if ! yes_no then
                part:SetDragCoefficient(100 * self.multiplier)
            else
                part:SetDragCoefficient(1)
            end

        end
        return false
    end

    local phys = prop:GetPhysicsObject()

    if !phys:IsValid() then return end

    phys:EnableGravity(yes_no)
    if yes_no then
        phys:SetDragCoefficient(1)
    else
        phys:SetDragCoefficient(100 * self.multiplier)
    end

end

function ENT:Static_Logic()

    local NewObjs = {}

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do
        self:Slow_Prop(contact , false)
        NewObjs[ contact:EntIndex() ] = contact
    end

    for idx,contact in pairs(self.objects) do
        if (NewObjs[ idx ] != contact) then
            self:Slow_Prop(contact , true)
        end
    end

    self.objects = NewObjs

end

function ENT:Static_Disable()

    for _,contact in pairs(self.objects) do
        self:Slow_Prop(contact , true)
    end

end

function ENT:PullPushProp(prop , vec)

    if prop:GetMoveType() == MOVETYPE_NONE then return false end

    if prop:GetMoveType() != MOVETYPE_VPHYSICS then
        if prop.AddVelocity then
            prop:AddVelocity(vec)
        else
            prop:SetVelocity(vec)
        end
    end

    if prop:GetPhysicsObjectCount() > 1 then
        for x = 0, prop:GetPhysicsObjectCount() - 1 do
            local part = prop:GetPhysicsObjectNum(x)
            part:AddVelocity(vec)
        end
        return false
    end

    local phys = prop:GetPhysicsObject()

    if !phys:IsValid() then return end

    phys:AddVelocity(vec)

end

function ENT:VelModProp(prop , mul)

    if prop:GetMoveType() == MOVETYPE_NONE then return false end

    if prop:GetMoveType() != MOVETYPE_VPHYSICS then
        local vel1 = prop:GetVelocity()
        vel1:Normalize()

        if prop.AddVelocity then
            prop:AddVelocity(vel1 * mul)
        else
            prop:SetVelocity(vel1 * mul)
        end
    end

    if prop:GetPhysicsObjectCount() > 1 then
        for x = 0, prop:GetPhysicsObjectCount() - 1 do
            local part = prop:GetPhysicsObjectNum(x)
            local vel2 = part:GetVelocity()
            vel2:Normalize()
            part:AddVelocity(vel2 * mul)
        end
        return false
    end

    local phys = prop:GetPhysicsObject()

    if (!phys:IsValid()) then return end

    local vel3 = phys:GetVelocity()
    vel3:Normalize()
    phys:AddVelocity(vel3 * mul)

end


function ENT:Pull_Logic()

    local center = self:GetPos()

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do

        local path = center-contact:GetPos()
        local length = math.max(path:Length(), 1e-5)
        path = path * self.multiplier * math.sqrt(math.max(1 - length / self.range, 0)) / length
        self:PullPushProp(contact , path)

    end

end

function ENT:Push_Logic()

    local center = self:GetPos()

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do

        local path = contact:GetPos() - center
        local length = math.max(path:Length(), 1e-5)
        path = path * self.multiplier / length
        self:PullPushProp(contact , path)

    end

end


function ENT:Push_Logic()

    local center = self:GetPos()

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do

        local path = contact:GetPos() - center
        local length = path:Length()
        path = path / length
        self:PullPushProp(contact , path * self.multiplier)

    end

end



function ENT:Push_Logic()

    local center = self:GetPos()

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do

        local path = contact:GetPos() - center
        local length = path:Length()
        path = path * (1.0 / length)
        self:PullPushProp(contact , path * self.multiplier)

    end

end

function ENT:Wind_Logic()

    local up = self.direction
    up:Normalize()

    for _,contact in pairs(self:GetEverythingInSphere(self:GetPos(), self.range)) do
        self:PullPushProp(contact , up * self.multiplier)
    end

end

function ENT:IsExcludedFromSphere(obj)
    return  !obj:IsValid()
            or self.ignore[ obj:EntIndex() ] == obj
            or IsFalse(self.workonplayers) and obj:IsPlayer()
            or obj:GetMoveType() == MOVETYPE_NOCLIP
            or !gamemode.Call("PhysgunPickup", self:GetCreator(), obj)
end

function ENT:GetEverythingInSphere()

    local pos = self:GetPos()
    local objects_in_sphere = {}

    is_valid_angle = self.arc >= 0 and self.arc < 360

    if is_valid_angle then
        local rgc = math.cos(math.rad(self.arc) / 2)
        local upvec = self:GetUp()

        for _, obj in ipairs(ents.FindInSphere(pos, self.range)) do
            if self:IsExcludedFromSphere(obj) then continue end

            local dir = obj:GetPos() - pos
            dir:Normalize()
            if dir:Dot(upvec) > rgc then
                table.insert(objects_in_sphere, obj)
            end
        end
    else
        for _, obj in ipairs(ents.FindInSphere(pos, self.range)) do
            if	self:IsExcludedFromSphere(obj) then continue end
            table.insert(objects_in_sphere, obj)
        end
    end

    return objects_in_sphere
end

function ENT:Vortex_Logic()

    local up = self.direction
    up:Normalize()
    local center = self:GetPos()

    for _,contact in pairs(self:GetEverythingInSphere()) do

        local path = contact:GetPos() + contact:GetVelocity() - center
        path:Normalize()
        self:PullPushProp(contact , path:Cross(up) * self.multiplier)

    end

end

function ENT:Flame_Apply(prop, activate_flame)

    if prop:GetMoveType() == MOVETYPE_NONE then return false end

    if activate_flame then
        prop:Ignite(self.multiplier , 0.0)
    else
        prop:Extinguish()
    end

end


function ENT:Flame_Logic()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        self:Flame_Apply(contact, true)
    end

end

function ENT:Flame_Disable()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        self:Flame_Apply(contact , false)
    end

end

function ENT:Crush_Apply(prop , yes_no)

    if yes_no == true then
        prop:TakeDamage(self.multiplier , self.pl)
    end

end

function ENT:Battery_Apply(prop , yes_no)

    local x,maxx

    if prop.Armor then

        x = prop:Armor() + self.multiplier
        maxx = prop:GetMaxHealth()

        if (x > maxx) then
            x = maxx
        end

        prop:SetArmor(x)

    end

end

function ENT:Health_Apply(prop , yes_no)

    local x,maxx

    if yes_no == true then

        x = prop:Health() + self.multiplier
        maxx = prop:GetMaxHealth()

        if (x > maxx) then
            x = maxx
        end

        prop:SetHealth(x)

    end

end

function ENT:Heal_Logic()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        if contact:IsNPC() or contact:IsPlayer() then
            self:Health_Apply(contact , true)
        end
    end

end

function ENT:Death_Logic()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        if contact:IsNPC() or contact:IsPlayer() then
            self:Crush_Apply(contact , true)
        end
    end

end

function ENT:Crush_Logic()

    for _, contact in pairs(self:GetEverythingInSphere()) do
        self:Crush_Apply(contact , true)
    end

end

function ENT:EMP_Apply(prop , active)
    if !prop or !prop.Inputs or !istable(prop.Inputs) then return end

    for k,v in pairs(prop.Inputs) do
        if EMP_IGNORE_INPUTS[k] == true or !prop.TriggerInput then continue end

        local value = prop.Inputs[k].Value
        if v.Type == "NORMAL" then
            if active then value = value + self.multiplier * math.Rand(-1, 1) end
        elseif v.Type == "VECTOR" then
            if active then value = value + self.multiplier * VectorRand(-1, 1) end
        else continue
        end
        prop:TriggerInput(k, value)
    end

end

function ENT:EMP_Logic()

    local NewObjs = {}

    for _,contact in pairs(self:GetEverythingInSphere()) do
        self:EMP_Apply(contact , true)
        NewObjs[ contact:EntIndex() ] = contact
    end

    for idx,contact in pairs(self.objects) do
        if (NewObjs[ idx ] != contact) then
            self:EMP_Apply(contact , false)
        end
    end

    self.objects = NewObjs

end

function ENT:EMP_Disable()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        self:EMP_Apply(contact , false)
    end

end

function ENT:WakeUp(prop)
    if prop == nil then return end

    if prop:GetMoveType() == MOVETYPE_VPHYSICS then

        if prop:GetPhysicsObjectCount() > 1 then
            for x = 0, prop:GetPhysicsObjectCount() - 1 do
                local part = prop:GetPhysicsObjectNum(x)
                part:Wake()
            end
            return false
        end

        local phys = prop:GetPhysicsObject()
        if (phys:IsValid()) then phys:Wake() end

    end
end

function ENT:NoCollide_Logic()

    local contact_ent_id
    local valid_objects = {}

    for _, contact in pairs(self:GetEverythingInSphere()) do

        contact_ent_id = contact:EntIndex()

        if self.ignore[ contact_ent_id ] == contact then continue end

        valid_objects[ contact_ent_id ] = true

        if !self.objects[ contact_ent_id ] and contact.SetCollisionGroup and contact.GetCollisionGroup then

            self.objects[ contact_ent_id ] = {}
            self.objects[ contact_ent_id ].old_group = contact:GetCollisionGroup()
            self.objects[ contact_ent_id ].obj = contact
            contact:SetCollisionGroup(COLLISION_GROUP_WORLD)
            self:WakeUp(contact)

        end

    end

    for idx, contact in pairs(self.objects) do
        if true != valid_objects[idx] and istable(contact) then

            if (contact.obj:IsValid()) then
                contact.obj:SetCollisionGroup(contact.old_group)
                self:WakeUp(contact.obj)
            end

            self.objects[idx] = nil

        end
    end

end

function ENT:NoCollide_Disable()

    for Idx,contact in pairs(self.objects) do
        if istable(contact) and contact.obj:IsValid() then
                contact.obj:SetCollisionGroup(contact.old_group)
                self:WakeUp(contact.obj)
        end
    end

    self.objects = {}

end

function ENT:Battery_Logic()

    for _,contact in pairs(self:GetEverythingInSphere()) do
        if contact:IsNPC() or contact:IsPlayer() then
            self:Battery_Apply(contact , true)
        end
    end

end

function ENT:Speed_Logic()
    for _,contact in pairs(self:GetEverythingInSphere()) do

        if (self.multiplier > 0) then
            self:VelModProp(contact , 1 + self.multiplier)
        elseif (self.multiplier < 0) then
            self:VelModProp(contact , -1 + self.multiplier)
        end

    end
end

local LogicFunctions = {
    ["Gravity"] = ENT.Gravity_Logic,
    ["Pull"] = ENT.Pull_Logic,
    ["Push"] = ENT.Push_Logic,
    ["Hold"] = ENT.Static_Logic,
    ["Wind"] = ENT.Wind_Logic,
    ["Vortex"] = ENT.Vortex_Logic,
    ["Flame"] = ENT.Flame_Logic,
    ["Crush"] = ENT.Crush_Logic,
    ["EMP"] = ENT.EMP_Logic,
    ["Death"] = ENT.Death_Logic,
    ["Heal"] = ENT.Heal_Logic,
    ["Battery"] = ENT.Battery_Logic,
    ["NoCollide"] = ENT.NoCollide_Logic,
    ["Speed"] = ENT.Speed_Logic
}

function ENT:Think()

    if IsTrue(self.ignoreself) then
        self:BuildIgnoreList()
    else
        self.ignore = {}
    end

    if self.active and LogicFunctions[self.FieldType] then
        LogicFunctions[self.FieldType](self)
    end

    self.BaseClass.Think(self)
end

local LogicDeactivateFunctions = {
    ["Gravity"] = ENT.Gravity_Disable,
    ["Hold"] = ENT.Static_Disable,
    ["Flame"] = ENT.Flame_Disable,
    ["EMP"] = ENT.EMP_Disable,
    ["Battery"] = ENT.Battery_Disable,
    ["NoCollide"] = ENT.NoCollide_Disable,
    ["Speed"] = ENT.Speed_Disable
}

function ENT:Disable()
    if LogicDeactivateFunctions[self.FieldType] then
        LogicDeactivateFunctions[self.FieldType](self)
    end

    self.BaseClass.Think(self)
end

function ENT:OnRemove()
    self:Disable()
end
