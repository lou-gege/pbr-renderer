using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

public class EnvLightSHGenerator : EditorWindow
{
    public Cubemap cubemap;
    private Vector3[] coefficients;
    private string folderPath = "Assets/ComputedMeshes/CubeMap";

    [MenuItem("Window/EnvLightSHGenerator")]
    static void Init()
    {
        EnvLightSHGenerator window = (EnvLightSHGenerator)EditorWindow.GetWindow(typeof(EnvLightSHGenerator));
        window.Show();
    }

    void OnGUI()
    {
        cubemap = EditorGUILayout.ObjectField("Cubemap", cubemap, typeof(Cubemap), false) as Cubemap;

        if (GUILayout.Button("Calculate SH Coefficients"))
        {
            if (cubemap == null)
            {
                Debug.LogError("No cubemap selected.");
                return;
            }

            coefficients = new Vector3[9];
            if (SphericalHarmonics.EnvLighting_SH_Project(cubemap, coefficients, 4096))
            {
                SaveCoefficientsToFile();
            }
        }
    }

    void SaveCoefficientsToFile()
    {
        if (!AssetDatabase.IsValidFolder("Assets/ComputedMeshes"))
        {
            AssetDatabase.CreateFolder("Assets", "ComputedMeshes");
        }
        if (!AssetDatabase.IsValidFolder(folderPath))
        {
            AssetDatabase.CreateFolder("Assets/ComputedMeshes", "CubeMap");
        }
        string fileName = "EnvCoeff_" + cubemap.name + ".txt";
        string filePath = folderPath + '/' + fileName;
        using (StreamWriter streamWriter = new StreamWriter(filePath))
        {
            foreach (Vector3 c in coefficients)
            {
                streamWriter.WriteLine(c.x + " " + c.y + " " + c.z);
            }
        }
        Debug.Log("SH Coefficients saved to: " + filePath);
    }
}
