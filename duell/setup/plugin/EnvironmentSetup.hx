package duell.setup.plugin;

import duell.helpers.PlatformHelper;
import duell.helpers.AskHelper;
import duell.helpers.DownloadHelper;
import duell.helpers.ExtractionHelper;
import duell.helpers.PathHelper;
import duell.helpers.LogHelper;
import duell.helpers.StringHelper;
import duell.helpers.ProcessHelper;
import duell.helpers.HXCPPConfigXMLHelper;

import duell.objects.HXCPPConfigXML;

import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class EnvironmentSetup
{
    private static var androidLinuxNDKPath = "http://dl.google.com/android/ndk/android-ndk-r8b-linux-x86.tar.bz2";
    private static var androidLinuxSDKPath = "http://dl.google.com/android/android-sdk_r22.0.5-linux.tgz";
    private static var androidMacNDKPath = "http://dl.google.com/android/ndk/android-ndk-r8b-darwin-x86.tar.bz2";
    private static var androidMacSDKPath = "http://dl.google.com/android/android-sdk_r22.0.5-macosx.zip";
    private static var androidWindowsNDKPath = "http://dl.google.com/android/ndk/android-ndk-r8b-windows.zip";
    private static var androidWindowsSDKPath = "http://dl.google.com/android/android-sdk_r22.0.5-windows.zip";
    private static var apacheAntUnixPath = "http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.2-bin.tar.gz";
    private static var apacheAntWindowsPath = "http://archive.apache.org/dist/ant/binaries/apache-ant-1.9.2-bin.zip";
    private static var javaJDKURL = "http://www.oracle.com/technetwork/java/javase/downloads/jdk6u37-downloads-1859587.html";

    /// RESULTING VARIABLES
    private var androidSDKPath : String = null;
    private var androidNDKPath : String = null;
    private var apacheANTPath : String = null;
    private var javaJDKPath : String = null;
    private var hxcppConfigPath : String = null;
    private var androidSDKInstallSkip : Bool = false;

    public function new()
    {

    }

    public function setup(args : Array<String>) : String
    {
        try
        {

            LogHelper.info("");
            LogHelper.info("\x1b[2m------");
            LogHelper.info("Android Setup");
            LogHelper.info("------\x1b[0m");
            LogHelper.info("");

            downloadAndroidSDK();

            LogHelper.println("");

            setupAndroidSDK();

            LogHelper.println("");

            downloadAndroidNDK();

            LogHelper.println("");

            downloadApacheAnt();

            LogHelper.println("");

            setupJDKInstallation();

            LogHelper.println("");

            setupHXCPP();

            LogHelper.info("\x1b[2m------");
            LogHelper.info("end");
            LogHelper.info("------\x1b[0m");

        } catch(error : Dynamic)
        {
            LogHelper.error("An error occurred, do you need admin permissions to run the script? Check if you have permissions to write on the paths you specify. Error:" + error);
        }

        return "success";
    }

    private function downloadAndroidSDK()
    {
        /// variable setup
        var downloadPath = "";
        var defaultInstallPath = "";
        var ignoreRootFolder = "android-sdk";

        if (PlatformHelper.hostPlatform == Platform.WINDOWS)
        {
            downloadPath = androidWindowsSDKPath;
            defaultInstallPath = "C:\\Development\\Android SDK";

        }
        else if (PlatformHelper.hostPlatform == Platform.LINUX)
        {
            downloadPath = androidLinuxSDKPath;
            defaultInstallPath = "/opt/android-sdk";
            ignoreRootFolder = "android-sdk-linux";
        }
        else if (PlatformHelper.hostPlatform == Platform.MAC)
        {
            downloadPath = androidMacSDKPath;
            defaultInstallPath = "/opt/android-sdk";
            ignoreRootFolder = "android-sdk-mac";
        }

        var downloadAnswer = AskHelper.askYesOrNo("Download the android SDK");

        /// ask for the instalation path
        androidSDKPath = AskHelper.askString("Android SDK Location", defaultInstallPath);

        /// clean up a bit
        androidSDKPath = PathHelper.unescape(androidSDKPath);
        androidSDKPath = StringHelper.strip(androidSDKPath);

        if(androidSDKPath == "")
            androidSDKPath = defaultInstallPath;

        if(downloadAnswer)
        {
            /// the actual download
            DownloadHelper.downloadFile(downloadPath);

            /// create the directory
            PathHelper.mkdir(androidSDKPath);

            /// the extraction
            ExtractionHelper.extractFile(Path.withoutDirectory(downloadPath), androidSDKPath, ignoreRootFolder);

            /// set appropriate permissions
            if(PlatformHelper.hostPlatform != Platform.WINDOWS)
            {
                ProcessHelper.runCommand("", "chmod", ["-R", "777", androidSDKPath], false);
            }
        }
    }

    private function setupAndroidSDK()
    {
        var install = AskHelper.askYesOrNo("Would you like to install necessary Android packages (API16 and 19, Platform-tools and tools)");

        if(!install)
        {
            LogHelper.println ("Please then make sure Android API 16 and SDK Platform-tools are installed");
            return;
        }

        var packageListOutput = ProcessHelper.runProcess(androidSDKPath + "/tools/", "./android", ["list", "sdk"]); /// numbers "taken from android list sdk --all"

        var rawPackageList = packageListOutput.split("\n");

        /// filter the actual package lines, lines starting like " 1-" or " 12-"
        var r = ~/^ *[0-9]+\-.*$/;
        rawPackageList = rawPackageList.filter(function(str) { return r.match(str); });

        /// filter the packages we want
        r = ~/(Android SDK Tools|Android SDK Platform|Android SDK Build-tools|SDK Platform Android 4.4.2, API 19|SDK Platform Android 4.1.2, API 16)/;
        var packageListWithNames = rawPackageList.filter(function(str) { return r.match(str); });

        /// retrieve only the number
        var packageNumberList = packageListWithNames.map(function(str) { return str.substr(0, str.indexOf("-")).ltrim(); });

        if(packageNumberList.length != 0)
        {
            LogHelper.info("Will download " + packageListWithNames.join(", "));
            ProcessHelper.runCommand(androidSDKPath + "/tools/", "./android", ["update", "sdk", "--no-ui", "--filter", packageNumberList.join(",")]); /// numbers "taken from android list sdk --all"
        }
        else
        {
            LogHelper.println("No packages to download.");
        }

        /// NOT SURE WHAT THIS IS FOR
        /*
		if (PlatformHelper.hostPlatform != Platform.WINDOWS && FileSystem.exists (Sys.getEnv ("HOME") + "/.android")) {

			ProcessHelper.runCommand ("", "chmod", [ "-R", "777", "~/.android" ], false);
			ProcessHelper.runCommand ("", "cp", [ PathHelper.getHaxelib (new Haxelib ("lime-tools")) + "/templates/bin/debug.keystore", "~/.android/debug.keystore" ], false);

		}
		*/
    }

    private function downloadAndroidNDK()
    {
        /// variable setup
        var downloadPath = "";
        var defaultInstallPath = "";
        var ignoreRootFolder = "android-ndk-r8b";

        if(PlatformHelper.hostPlatform == Platform.WINDOWS)
        {
            downloadPath = androidWindowsNDKPath;
            defaultInstallPath = "C:\\Development\\Android NDK";
        }
        else if (PlatformHelper.hostPlatform == Platform.LINUX)
        {
            downloadPath = androidLinuxNDKPath;
            defaultInstallPath = "/opt/android-ndk";
        }
        else
        {
            downloadPath = androidMacNDKPath;
            defaultInstallPath = "/opt/android-ndk";
        }

        /// check if the user wants to download the android ndk
        var downloadAnswer = AskHelper.askYesOrNo("Download the android NDK");

        /// ask for the instalation path
        androidNDKPath = AskHelper.askString("Android NDK Location", defaultInstallPath);

        /// clean up a bit
        androidNDKPath = PathHelper.unescape(androidNDKPath);
        androidNDKPath = StringHelper.strip(androidNDKPath);

        if(androidNDKPath == "")
            androidNDKPath = defaultInstallPath;

        if(downloadAnswer)
        {
            /// the actual download
            DownloadHelper.downloadFile(downloadPath);

            /// create the directory
            PathHelper.mkdir(androidNDKPath);

            /// the extraction
            ExtractionHelper.extractFile(Path.withoutDirectory(downloadPath), androidNDKPath, ignoreRootFolder);
        }
    }

    private function downloadApacheAnt()
    {
        /// variable setup
        var downloadPath = "";
        var defaultInstallPath = "";
        var ignoreRootFolder = "apache-ant-1.9.2";

        if (PlatformHelper.hostPlatform == Platform.WINDOWS)
        {
            downloadPath = apacheAntWindowsPath;
            defaultInstallPath = "C:\\Development\\Apache Ant";
        }
        else
        {
            downloadPath = apacheAntUnixPath;
            defaultInstallPath = "/opt/apache-ant";
        }

        /// check if the user wants to download apache ant
        var downloadAnswer = AskHelper.askYesOrNo("Download Apache Ant");

        /// ask for the instalation path
        apacheANTPath = AskHelper.askString("Apache Ant Location", defaultInstallPath);

        /// clean up a bit
        apacheANTPath = PathHelper.unescape(apacheANTPath);
        apacheANTPath = StringHelper.strip(apacheANTPath);

        if(apacheANTPath == "")
            apacheANTPath = defaultInstallPath;

        if(downloadAnswer)
        {
            /// the actual download
            DownloadHelper.downloadFile(downloadPath);

            /// create the directory
            PathHelper.mkdir(apacheANTPath);

            /// the extraction
            ExtractionHelper.extractFile(Path.withoutDirectory(downloadPath), apacheANTPath, ignoreRootFolder);
        }
    }

    private function setupJDKInstallation()
    {
        if (PlatformHelper.hostPlatform != Platform.MAC)
        {
            var defaultInstallPath;
            if(PlatformHelper.hostPlatform == Platform.WINDOWS)
            {
                defaultInstallPath = "C:\\Program Files\\Java\\jdk1.7.0\\";
            }
            else /// Linux
            {
                defaultInstallPath = "/opt/jdk";
            }

            var answer = AskHelper.askYesOrNo("Download and install the Java JDK");

            if (answer)
            {
                LogHelper.println ("You must visit the Oracle website to download the Java 6 JDK for your platform");
                var secondAnswer = AskHelper.askYesOrNo("Would you like to go there now?");

                if (secondAnswer)
                {
                    ProcessHelper.openURL(javaJDKURL);
                }
            }

            javaJDKPath = AskHelper.askString("Java JDK Location", defaultInstallPath);

            /// clean up a bit
            javaJDKPath = PathHelper.unescape(javaJDKPath);
            javaJDKPath = StringHelper.strip(javaJDKPath);

            if(javaJDKPath == "")
                javaJDKPath = defaultInstallPath;
        }
    }

    private function setupHXCPP()
    {
        hxcppConfigPath = HXCPPConfigXMLHelper.getProbableHXCPPConfigLocation();

        if(hxcppConfigPath == null)
        {
            LogHelper.error("Could not find the home folder, no HOME variable is set. Can't find hxcpp_config.xml");
        }

        var hxcppXML = HXCPPConfigXML.getConfig(hxcppConfigPath);

        var existingDefines : Map<String, String> = hxcppXML.getDefines();

        var newDefines : Map<String, String> = getDefinesToWriteToHXCPP();

        LogHelper.info("\x1b[1mWriting new definitions to hxcpp config file:\x1b[0m");

        for(def in newDefines.keys())
        {
            LogHelper.info("\x1b[1m" + def + "\x1b[0m:" + newDefines.get(def));
        }

        for(def in existingDefines.keys())
        {
            if(!newDefines.exists(def))
            {
                newDefines.set(def, existingDefines.get(def));
            }
        }

        hxcppXML.writeDefines(newDefines);
    }

    private function getDefinesToWriteToHXCPP() : Map<String, String>
    {
        var defines = new Map<String, String>();

        if(FileSystem.exists(androidSDKPath))
        {
            defines.set("ANDROID_SDK", FileSystem.fullPath(androidSDKPath));
        }
        else
        {
            LogHelper.error("Path specified for android SDK doesn't exist!");
        }

        if(FileSystem.exists(androidNDKPath))
        {
            defines.set("ANDROID_NDK_ROOT", FileSystem.fullPath(androidNDKPath));
        }
        else
        {
            LogHelper.error("Path specified for android NDK doesn't exist!");
        }

        if(FileSystem.exists(apacheANTPath))
        {
            defines.set("ANT_HOME", FileSystem.fullPath(apacheANTPath));
        }
        else
        {
            LogHelper.error("Path specified for apache Ant doesn't exist!");
        }

        if(PlatformHelper.hostPlatform != Platform.MAC)
        {
            if(FileSystem.exists(javaJDKPath))
            {
                defines.set("JAVA_HOME", FileSystem.fullPath(javaJDKPath));
            }
            else
            {
                LogHelper.error("Path specified for Java JDK doesn't exist!");
            }
        }


        defines.set("ANDROID_SETUP", "YES");

        return defines;
    }
}