local TweenService = {}

local attachment: Attachment? = nil
local linearVelocity: LinearVelocity? = nil
local targetPosition: Vector3? = nil

local runService: RunService = game:GetService("RunService")
local noClipConnection: RBXScriptConnection? = nil

local tweening = false
local speed = 20
local runningstate = true

function TweenService.SetSpeed(newSpeed: number)
    speed = newSpeed
end

function TweenService.ChangeRunningState(state: boolean)
    runningstate = state
end


function TweenService.AwaitTween()
    local localPlayer: Player = game:GetService("Players").LocalPlayer
    while tweening do
        local char: Model? = localPlayer.Character :: Model?

        if not char or char:FindFirstChild("HumanoidRootPart") then
            warn("[TweenService] While awaiting tween char or root has been destroyed")
            tweening = false 
            return 
        end

        task.wait()
    end
end

local function CleanUp()
    if attachment then
        attachment:Destroy()
        attachment = nil
    end

    if linearVelocity then
        linearVelocity:Destroy()
        linearVelocity = nil
    end

    targetPosition = nil
end

local function CreateLinearVelocity(char: Model, root: BasePart)
    -- Clean up any previous constraint before creating new one
    CleanUp()

    local newAttachment: Attachment = Instance.new("Attachment")
    newAttachment.Name = "MoveAttachment"
    newAttachment.Parent = root

    attachment = newAttachment

    local newLinearVelocity: LinearVelocity = Instance.new("LinearVelocity")
    newLinearVelocity.Name = "Tween"
    newLinearVelocity.Attachment0 = newAttachment
    newLinearVelocity.MaxForce = math.huge
    newLinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
    newLinearVelocity.Enabled = false
    newLinearVelocity.Parent = char

    linearVelocity = newLinearVelocity
end

local function NoClip(state: boolean, root: BasePart): nil
    local parent = root.Parent

    if parent == nil then
        warn("[TweenService] NoClip called but root has no parent; cannot modify collisions")
        return
    end

    if noClipConnection then 
        noClipConnection:Disconnect()
        noClipConnection = nil
    end

    if state then 
        print("[TweenService] Enabled NoClip")       
        noClipConnection = runService.PreSimulation:Connect(function()
            for _, inst: Instance in pairs(parent:GetDescendants()) do
                if inst:IsA('BasePart') and inst.CanCollide then
                    inst.CanCollide = false
                end
            end
        end)
    else
        for _, inst: Instance in pairs(parent:GetDescendants()) do
            if inst:IsA('BasePart') and inst.CanCollide then
                inst.CanCollide = true
            end
        end
    end


    return
end

local function MoveToLocation(position: Vector3, root: BasePart): nil
    targetPosition = position

    if not linearVelocity then
        warn("[TweenService] MoveToLocation called with nil LinearVelocity; aborting tween")
        return
    end

    NoClip(true, root)

    linearVelocity.Enabled = true

    task.spawn(function()
        while tweening do

            if not runningstate then 
                warn("[TweenService] runningstate false")
                tweening = false
                break
            end

            if not root or not root.Parent then
                warn("[TweenService] HumanoidRootPart or its parent was destroyed during tween; stopping tween")
                tweening = false
                break
            end

            if not targetPosition then
                warn("[TweenService] targetPosition became nil during tween; stopping tween")
                tweening = false
                break
            end

            local currentPos: Vector3 = root.Position
            local toTarget: Vector3 = targetPosition - currentPos
            local distance: number = toTarget.Magnitude

            local stopDistance: number = 1

            if distance <= stopDistance then
                linearVelocity.VectorVelocity = Vector3.new(0, 0, 0)
                task.wait(0.1)
                linearVelocity.Enabled = false
                targetPosition = nil
                tweening = false
                break
            end

            local direction: Vector3 = toTarget.Unit
            linearVelocity.VectorVelocity = direction * speed

            task.wait()
        end

        NoClip(false, root)
    end)

    return
end

function TweenService.TweenPlayer(location: Vector3): nil
    print(string.format("[TweenService] Starting tween to position %s", tostring(location)))

    -- If currently tweening, wait for it to finish first
    if tweening then
        print("[TweenService] Existing tween in progress; awaiting completion before starting new tween")
        TweenService.AwaitTween()
    end

    local localPlayer: Player = game:GetService("Players").LocalPlayer
    local char: Model = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local root: BasePart? = char:FindFirstChild("HumanoidRootPart") :: BasePart?

    if root == nil then
        warn("[TweenService] HumanoidRootPart not found for player; cannot start tween")
        return
    end

    tweening = true

    CreateLinearVelocity(char, root)
    MoveToLocation(location, root)

    print("[TweenService] Awaiting tween completion")
    TweenService.AwaitTween()
    CleanUp()

    print("[TweenService] Tween completed and resources cleaned up")
    return
end

return TweenService :: any
