--file://C:/castle/castle-tube/main.lua

local x3 = require('x3/x3', {root = true});

local Materials = require("materials")(x3);

local TRACK_RADIUS = 128;
local TRACK_ARC = 110/128;

local scene = x3.newEntity();
local camera = x3.newCamera();

local playerGroup = x3.newEntity();
local obstacleGroup = x3.newEntity();
obstacleGroup:setPosition(-TRACK_RADIUS, 0, 0);

scene:add(playerGroup);
scene:add(obstacleGroup);
playerGroup:add(camera);

local canvas;

local WorldAngle = 0;
local WorldSpin = 0;
local TimeShift = 0;
local TimeAlive = 0;
local LevelNumber = 0

local defaultShade = [[

    vec2 uv = v_TexCoord0;

    vec2 diff = abs(uv - vec2(0.5));
    float eyeDist = length(u_WorldCameraPosition - v_WorldPosition);
    float darken = 1.0 / pow(eyeDist, u_Shininess);

    if (max(diff.x, diff.y) > 0.46) {

        vec3 color = u_EmissiveColor * darken;
        return vec4(color,1);

    } else {

        vec3 color = u_BaseColor * darken;
        return vec4(color,1);
    }

]]

local lineShaderOpts = {

    vertMain = [[

        const float PI = 3.14159;

        mat4 AAm4(vec4 axisAngle) {
            vec3 axis = normalize(axisAngle.xyz);
            float s = sin(axisAngle.w);
            float c = cos(axisAngle.w);
            float oc = 1.0 - c;
            
            return mat4(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0,
                oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0,
                oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0,
            0, 0, 0, 1
                );
        }
        
        mat4 Tm4(vec3 translation) {
            
            return mat4(
            1, 0, 0, 0, 
            0, 1, 0, 0,
            0, 0, 1, 0,
            translation.x, translation.y, translation.z, 1.0
            );
            
        }
        extern highp float u_GameTime;

        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            #if INSTANCES
                mat4 model = u_Model * mat4(InstanceTransform1, InstanceTransform2, InstanceTransform3, InstanceTransform4);
            #else
                mat4 model = u_Model;
            #endif

            vec3 pt = vec3(128, 0, 0);
            vec3 dir = vec3(0, 1, 0);

            float arc = (VertexPosition.z / 32.0) * (PI/2.0) - u_GameTime;

            vec4 vpos = vec4(VertexPosition.x, VertexPosition.y, 0.0, 1.0);

            mat4 shifter = Tm4(-pt) * AAm4(vec4(dir, arc)) * Tm4(vec3(pt));
            
            //mat4 shifter = Tm4(vec3(0,0,VertexPosition.z));
            
            
           vec4 worldPosition = model * (shifter * vpos);
           //vec4 worldPosition = model * VertexPosition;
            v_WorldPosition = worldPosition.xyz;
            v_WorldNormal = normalize((model * vec4(VertexNormal, 0.0))).xyz;
            v_TexCoord0 = VertexTexCoord.xy;

            return u_ViewProjection * worldPosition;
        }
    ]],


    fragShade = defaultShade,

    cullMode = "none"
}

local tubeShader = x3.shader.newCustom(lineShaderOpts);
local tubeMaterial = x3.material.newCustom(tubeShader,
    {
        u_GameTime = 0,
        u_BaseColor = {1,0.7,0.7},
        u_EmissiveColor = x3.COLOR.GRAY3,
        u_Shininess = 0.46
    }
);

local lineShader = x3.shader.newCustom({
    fragShade = defaultShade
});

local playerMaterial = x3.material.newCustom(lineShader, {
    u_BaseColor = {0.5,0.5,1},
    u_EmissiveColor = x3.COLOR.GRAY1,
    u_Shininess = 0.1
});


local objects = {
    tube = x3.newEntity(
        x3.mesh.newCylinder(1, 120, 12, 256),
        tubeMaterial
    ),

    player = x3.newEntity(
        x3.mesh.newBox(0.2, 0.2, 0.2),
        playerMaterial
    )
};


scene:add(objects.tube);

camera:setPosition(0, -0.2, -3.5);
camera:lookAt(x3.vec3(0,0,1), x3.vec3(0,1,0));

playerGroup:add(objects.player);
objects.player:setPosition(0,-0.9,0.0);


local hazardMesh = x3.mesh.newCylinder(0.05, 2, 16, 1);
local hazardMat = x3.material.newLit(
--[[    
lineShader,
    {
        u_BaseColor = {1,0,0},
        u_EmissiveColor = x3.COLOR.GRAY2,
        u_Shininess = 0.1
    }]]

    {
        emissiveColor = {1,0,0}
    }
)

local Z_AXIS = x3.vec3(0,0,1);
local Y_AXIS = x3.vec3(0,1,0);

local objRings = {};

local function makeHazards(numHazards)

    for i = 1, numHazards do

        local angle = (i/numHazards) * (math.pi * 2)*(TRACK_ARC) + 0.04;
    
        local hazGroup = x3.newEntity();
        local spinGroup = x3.newEntity();
    
    
        local laser = x3.newEntity(
            hazardMesh,
            Materials.RedLaser
        );
    
        obstacleGroup:add(hazGroup);
        hazGroup:add(spinGroup);
        
        hazGroup:rotateAxis(Y_AXIS, -angle);
        hazGroup:setPosition(math.cos(angle) * TRACK_RADIUS, 0, math.sin(angle) * TRACK_RADIUS);
        
        spinGroup:add(laser);

        local spin = math.random() * math.pi * 2;

        spinGroup:rotateAxis(Z_AXIS, spin);
    
        laser:setPosition(0.0, 1, 0);
        laser:rotateRelX(math.pi * 0.5);
    
        
        laser.renderOrder = numHazards - i;

        objRings[i] = {
            spin = spin,
            angle = angle
        }
   
    
    end    

end



local collisionIndex = 1;

local spinTemp = x3.vec3();

local function areClose(a, b, amt)
    return math.abs(a-b) < amt;
end

local PI2 = math.pi * 2;
local PI = math.pi;

local function angleDistance(a, b)
    local phi = math.abs(b - a) % PI2;
    if (phi > PI) then return (PI2 - phi) else return phi end;
end


local function setLevel(n)

    LevelNumber = n;

    obstacleGroup:clearChildren();
    collisionIndex = 1;
    --makeHazards(math.floor(100 * (1 + math.pow(LevelNumber, 0.5))));
    makeHazards(150);
    TimeShift = TimeShift + 0.02;

end

local function restart()

    WorldAngle = -0.15;
    WorldSpin = 0;

    TimeShift = 0.06;
    TimeAlive = 0;
    
    setLevel(1);
end

local LastScore = 0;
local ShowScore = 0

local function die()

    LastScore = math.floor(TimeAlive) + LevelNumber * 20;
    print(TimeAlive, LevelNumber);

    restart();
    WorldAngle = -0.38;

    ShowScore = 4;

end


function love.load()
    restart();
end

local function checkCollision()

    local ring = objRings[collisionIndex];

    if (not ring) then
        return;
    end

    local spin = ring.spin;
    local angle = ring.angle;


    --print(ring.angle, WorldAngle);

    if (WorldAngle - angle > 0.02) then
        collisionIndex = collisionIndex + 1;
    elseif (areClose(angle, WorldAngle, 0.001)) then
        --print("touching");

        local playerZ = playerGroup:getRelYAxis();
        spinTemp:set(math.sin(spin), math.cos(spin), 0.0);

        local dist = angleDistance(spin, WorldSpin);

        if (areClose(dist, 0, 0.2) or areClose(dist, PI, 0.2)) then
            --print("hit", collisionIndex);
            die();
            return;
        else
            --print("no hit", collisionIndex);
        end

        collisionIndex = collisionIndex + 1;

        
    end
end

local Paused = false;

function love.keypressed(key)
    if (key == "space") then
        Paused = not Paused;
    end

    if (key == "n") then
        setLevel(LevelNumber + 1);
        WorldAngle = -0.1;
    end

    if (key == "r") then
        restart();
    end
end

function love.update(dt)
   
   -- objects.tube:rotateRelZ(dt);
   --tubeMaterial.uniforms.u_GameTime = tubeMaterial.uniforms.u_GameTime + dt * 0.05;

    if (Paused) then
        return;
    end

   WorldAngle = WorldAngle + dt * TimeShift;

   TimeAlive = TimeAlive + dt;

   tubeMaterial.uniforms.u_GameTime = WorldAngle;

   obstacleGroup:resetRotation();
   obstacleGroup:rotateRelY(WorldAngle);

   local down = love.keyboard.isDown;

   local rotSpeed = 0;

   if down("a") or down("left") then
        rotSpeed = 2 * dt;
   elseif down("d") or down("right") then
        rotSpeed = -2 * dt;
   end


   WorldSpin = WorldSpin + rotSpeed;

   playerGroup:resetRotation();
   playerGroup:rotateRelZ(WorldSpin);

   if (WorldAngle > (PI2 - 0.4)) then
        print("new level", WorldAngle, PI2 - 0.2)
        setLevel(LevelNumber + 1)
        WorldAngle = WorldAngle - PI2;
   end

   if (ShowScore > 0.0) then

    ShowScore = ShowScore - dt;

   end

   checkCollision();

   


end

function love.resize()

    local width, height = love.graphics.getDimensions();
    camera:setPerspective(50, height/width, 0.1, 120.0)

    canvas = x3.newCanvas3D(width, height);

    print(width, height);

end

love.resize();

function love.draw()

    x3.render(camera, scene, canvas);

    x3.displayCanvas3D(canvas, 0, 0, {
        clearColor = {1,1,1}
    });


    if (WorldAngle < 0.0) then
        love.graphics.setColor(0.6, 0.8, 0.8);
        love.graphics.print("Level: "..LevelNumber, 10, 10);
    end

    if (ShowScore > 0.0) then
        
        local w,h = love.graphics.getDimensions();

        local alpha = ShowScore / 6;

        love.graphics.setColor(1,0.5,0.5, alpha);
        love.graphics.rectangle("fill", 0, 0, w, h);

        love.graphics.setColor(1,1,1)
        love.graphics.print("GameOver! Score: "..LastScore, 10, 40);

    end
    
    love.graphics.setColor(1,1,1)

end