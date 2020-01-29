local package = function(x3)    
    local LaserShader = x3.shader.newCustom({

        fragShade = [[

            vec3 normal = getNormal();
            vec3 eyeRay =  u_WorldCameraPosition - v_WorldPosition;

            float eyeDist = length(eyeRay);
            

            float away = max(0.0, dot(normal, normalize(eyeRay)));

            away += sin(u_Time * 10.0) * 0.01;

            outColor.rgb = u_BaseColor * (1.0 + 10.0 * pow(away, 40.0));
            outColor.a = away / clamp((eyeDist * 0.15), 1.0, 1000.0);

            if (v_TexCoord0.y > 0.95 || v_TexCoord0.y < 0.05) {
                outColor.rgba = vec4(0.1,0.1,0.1,1.0);
            }
        ]]

    --        blendMode = "add"

    });

    local RedLaserMaterial = x3.material.newCustom(
        LaserShader,
        {
            u_BaseColor = {1,0.13,0.1}
        }
    );


    return {
        RedLaser = RedLaserMaterial
    }

end

return package;