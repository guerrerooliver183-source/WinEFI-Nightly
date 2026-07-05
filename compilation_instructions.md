# Instrucciones de Compilación para `winefi.exe`

Para compilar el archivo `winefi.cs` en un ejecutable `winefi.exe`, necesitarás el compilador de C# (`csc.exe`) que viene incluido con el .NET Framework en Windows. No es necesario instalar Visual Studio completo.

## Requisitos

*   Un sistema operativo Windows con .NET Framework instalado (generalmente viene preinstalado en versiones modernas de Windows).

## Pasos para la Compilación

1.  **Abre la Consola de Desarrollador para Visual Studio (o Símbolo del Sistema con variables de entorno de .NET):**
    *   La forma más sencilla es buscar en el menú de inicio "**Developer Command Prompt for VS**" (Símbolo del sistema para desarrolladores de VS) y abrirlo. Esto configurará automáticamente las variables de entorno necesarias para usar `csc.exe`.
    *   Si no tienes Visual Studio, puedes abrir un Símbolo del Sistema (CMD) normal y navegar a la ruta donde se encuentra `csc.exe`. Típicamente, esta ruta es similar a `C:\Windows\Microsoft.NET\Framework\v4.0.30319` (la versión puede variar).

2.  **Navega al Directorio del Archivo `winefi.cs`:**
    *   Usa el comando `cd` para ir a la carpeta donde guardaste `winefi.cs`.
    
    ```cmd
    cd C:\ruta\a\tu\carpeta
    ```

3.  **Compila el Código Fuente:**
    *   Ejecuta el siguiente comando para compilar `winefi.cs`:
    
    ```cmd
    csc.exe /target:winexe /out:winefi.exe winefi.cs
    ```
    
    *   **Explicación de los parámetros:**
        *   `/target:winexe`: Indica que el resultado debe ser un ejecutable de Windows (sin ventana de consola visible).
        *   `/out:winefi.exe`: Especifica el nombre del archivo de salida como `winefi.exe`.
        *   `winefi.cs`: Es el archivo de código fuente que se va a compilar.

4.  **Verifica la Compilación:**
    *   Después de ejecutar el comando, deberías encontrar un archivo llamado `winefi.exe` en el mismo directorio donde se encuentra `winefi.cs`.

Una vez que tengas `winefi.exe`, puedes colocarlo junto con los scripts de PowerShell (`WinEFI_Startup.ps1` y `ExtractBootres.ps1`) y el script de Inno Setup (`WinEFI_Installer.iss`) para compilar el instalador final.
