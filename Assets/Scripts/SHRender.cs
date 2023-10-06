using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class SHRender : MonoBehaviour
{
    public Cubemap cubemap;
    // Start is called before the first frame update
    void Start()
    {
        string EnvCoeffFileName = "Assets/ComputedMeshes/CubeMap/EnvCoeff_" + cubemap.name + ".txt";
        if (File.Exists(EnvCoeffFileName))
        {
            string[] lines = File.ReadAllLines(EnvCoeffFileName);
            Vector4[] coefficients = new Vector4[9];
            for (int i = 0; i < 9; i++)
            {
                string[] values = lines[i].Split(' ');
                coefficients[i] = new Vector4(float.Parse(values[0]), float.Parse(values[1]), float.Parse(values[2]), 0);
            }
            Renderer renderer = GetComponent<Renderer>();
            Material newMaterial = new Material(Shader.Find("NewPBR/SHShader"));
            newMaterial.SetVectorArray("_EnvCoefficients", coefficients);
            renderer.material = newMaterial;
        }
        else
        {
            Debug.LogError("No EnvCoefficients file found for cubemap: " + cubemap.name);
        }
    }

    // Update is called once per frame
    void Update()
    {

    }
}
