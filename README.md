# pbr-renderer

Diffuse(SH) + Specular(IBL) + Clear Coat

![Alt text](Blue_Metal_ClearCoat.png)

## Usage

- 一张新的CubeMap需要先在Window-EnvLightSHGenerator中生成CubeMap SH 系数
- GameObject需要挂载PRT和SHRender两个脚本，然后将CubeMap给到SHRender，然后运行即可