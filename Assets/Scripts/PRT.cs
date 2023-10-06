using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;

public class PRT : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        Mesh mesh = meshFilter.mesh;
        string MeshFilePath = "Assets/ComputedMeshes/computed_" + mesh.name + ".asset";
        if (mesh.name.Split('_')[0] != "computed")
        {
            if (File.Exists(MeshFilePath))
            {
                meshFilter.sharedMesh = AssetDatabase.LoadAssetAtPath<Mesh>(MeshFilePath);
                Debug.Log("use computed light transport coefficients");
                return;
            }
            if (!AssetDatabase.IsValidFolder("Assets/ComputedMeshes"))
            {
                AssetDatabase.CreateFolder("Assets", "ComputedMeshes");
            }
            Mesh newMesh = Instantiate(meshFilter.sharedMesh);
            Vector2[] uv2 = new Vector2[mesh.vertexCount];
            Vector2[] uv3 = new Vector2[mesh.vertexCount];
            Vector2[] uv4 = new Vector2[mesh.vertexCount];
            Color[] colors = new Color[mesh.vertexCount];

            for (int v = 0; v < newMesh.vertexCount; ++v)
            {
                //transform to world coordinate
                Vector3 vertex_world_position = transform.localToWorldMatrix.MultiplyPoint(newMesh.vertices[v]);
                Vector3 world_normal = transform.localToWorldMatrix.MultiplyVector(newMesh.normals[v]);

                float[] coefficients = new float[9];
                SphericalHarmonics.Transport_SH_Project(vertex_world_position, world_normal, coefficients, 4096);

                //put 9 coefficients to color uv2 uv3 uv4
                colors[v] = new Color(coefficients[0], coefficients[1], coefficients[2], coefficients[3]);
                uv2[v] = new Vector2(coefficients[4], coefficients[5]);
                uv3[v] = new Vector2(coefficients[6], coefficients[7]);
                uv4[v] = new Vector2(coefficients[8], 0);
            }

            Debug.Log("light transport has computed");

            newMesh.colors = colors;
            newMesh.uv2 = uv2;
            newMesh.uv3 = uv3;
            newMesh.uv4 = uv4;
            newMesh.UploadMeshData(true);

            AssetDatabase.CreateAsset(newMesh, MeshFilePath);
            meshFilter.sharedMesh = newMesh;
        }
    }

    // Update is called once per frame
    void Update()
    {

    }
}
