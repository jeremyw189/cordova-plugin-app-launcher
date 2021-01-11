cordova-plugin-map-launcher
===========================
This Cordova plugin has major modification from [@nchutchind](https://github.com/nchutchind) version. Please use his version.
Simple Cordova plugin to see if other apps are installed and launch them.
This is a fork of Nicholas Hutchind's cordova-plugin-app-launcher.
This fork has been greatly modified to launch an android aar library activity. Also extensive custom modification for IOS to launch ARCGIS map service.

## 0. Index
1. [Description](#1-description)
2. [Installation](#2-installation)
3. [Usage](#3-usage)
4. [Changelog](#4-changelog)
5. [Credits](#5-credits)
6. [License](#6-license)

## 1. Description

This plugin will launch an android app or an  activity in an  embeded aar  library. For IOS this app is customized to open to open an arcgis map for navigation.



## 2. Installation

### Automatically (CLI / Plugman)

```
$ cordova plugin add https://github.com/jaybowman/cordova-plugin-app-launcher.git
```
and then (this step will modify your project):
```
$ cordova prepare
```

1\. Add the following xml to your `config.xml`:
```xml
<!-- for iOS -->
<feature name="Launcher">
	<param name="ios-package" value="Launcher" />
</feature>
<!-- 
Additionally, for iOS 9+, you may need to install the cordova-plugin-queries-schemes plugin, which will allow whitelisting of what URLs your app will be allowed to launch. 

cordova plugin add cordova-plugin-queries-schemes
-->
```
```xml
<!-- for Android -->
<feature name="Launcher">
	<param name="android-package" value="com.hutchind.cordova.plugins.launcher.Launcher" />
</feature>
```

2\. Add `www/Launcher.js` to your project and reference it in `index.html`:
```html
<script type="text/javascript" src="js/Launcher.js"></script>
```

3\. iOS: 
	After the plugin is installed you will get a pod install error. You need to update the podfile and change the ios platform to 12.2 or greater. Then from the  platforms/ios folder run pod install.


## 3. Usage
```javascript
	// Default handlers
	var successCallback = function(data) {
		alert("Success!");
		// if calling canLaunch() with getAppList:true, data will contain an array named "appList" with the package names of applications that can handle the uri specified.
	};
	var errorCallback = function(errMsg) {
		alert("Error! " + errMsg);
	}
```

<i>AndroidManifest.xml:</i>
```xml
	<activity
		android:name="org.peekvision.lite.android.visualacuity.VisualAcuityActivity">
		<intent-filter>
			<action android:name="org.peekvision.intent.action.TEST_ACUITY"/>
			<category android:name="android.intent.category.DEFAULT"/>
		</intent-filter>
	</activity>
```

<i>Typescript:</i>
```typescript
	let actionName = 'org.peekvision.intent.action.TEST_ACUITY';

	window["plugins"].launcher.canLaunch({actionName: actionName},
		data => console.log("Peek Acuity can be launched"),
		errMsg => console.log("Peek Acuity not installed! " + errMsg)
	);
```

Launch Peek Acuity via an Action Name with Extras and return results (**Android**)
```typescript
	let actionName = 'org.peekvision.intent.action.TEST_ACUITY';

	let extras = [
	  {"name":"progressionLogMarArray", "value":[1.0,0.8,0.6,0.3,0.1],"dataType":"DoubleArray"},
	  {"name":"instructions",	"value":"none",		"dataType":"String"},
	  {"name":"eye",		"value":"left",		"dataType":"String"},
	  {"name":"beyondOpto",		"value":true,		"dataType":"Boolean"},
	  {"name":"testDistance",	"value":"4m",		"dataType":"String"},
	  {"name":"displayResult",	"value":false,		"dataType":"Boolean"},
	  {"name":"return_result",	"value":true,		"dataType":"Boolean"}
	];

	window["plugins"].launcher.launch({actionName: actionName, extras: extras},
		json => {
			if (json.isActivityDone) {
				if (json.data) {
					console.log("data=" + json.data);
				}
				if (json.extras) {
					if (json.extras.logMar) {
						console.log("logMar=" + json.extras.logMar);
					}
					if (json.extras.averageLux) {
						console.log("averageLux=" + json.extras.averageLux);
					}
				} else {
					console.log("Peek Acuity done but no results");
				}
			} else {
				console.log("Peek Acuity launched");
			}
		},
		errMsg => console.log("Peek Acuity error launching: " + errMsg)
	 );
```

# Extras Data Types

Most datatypes that can be put into an Android Bundle are able to be passed in. You must provide the datatype to convert to.
Only Uri Parcelables are supported currently.
```javascript
	extras: [
		{"name":"myByte", "value":1, "dataType":"Byte"},
		{"name":"myByteArray", "value":[1,0,2,3], "dataType":"ByteArray"},
		{"name":"myShort", "value":5, "dataType":"Short"},
		{"name":"myShortArray", "value":[1,2,3,4], "dataType":"ShortArray"},
		{"name":"myInt", "value":2000, "dataType":"Int"},
		{"name":"myIntArray", "value":[12,34,56], "dataType":"IntArray"},
		{"name":"myIntArrayList", "value":[123,456,789], "dataType":"IntArrayList"},
		{"name":"myLong", "value":123456789101112, "dataType":"Long"},
		{"name":"myLongArray", "value":[123456789101112,121110987654321], "dataType":"LongArray"},
		{"name":"myFloat", "value":12.34, "dataType":"Float"},
		{"name":"myFloatArray", "value":[12.34,56.78], "dataType":"FloatArray"},
		{"name":"myDouble", "value":12.3456789, "dataType":"Double"},
		{"name":"myDoubleArray", "value":[12.3456789, 98.7654321], "dataType":"DoubleArray"},
		{"name":"myBoolean", "value":false, "dataType":"Boolean"},
		{"name":"myBooleanArray", "value":[true,false,true], "dataType":"BooleanArray"},
		{"name":"myString", "value":"this is a test", "dataType":"String"},
		{"name":"myStringArray", "value":["this","is", "a", "test"], "dataType":"StringArray"},
		{"name":"myStringArrayList", "value":["this","is","a","test"], "dataType":"StringArrayList"},
		{"name":"myChar", "value":"T", "dataType":"Char"},
		{"name":"myCharArray", "value":"this is a test", "dataType":"CharArray"},
		{"name":"myCharSequence", "value":"this is a test", "dataType":"CharSequence"},
		{"name":"myCharSequenceArray", "value":["this","is a", "test"], "dataType":"CharSequenceArray"},
		{"name":"myCharSequenceArrayList", "value":["this","is a", "test"], "dataType":"CharSequenceArrayList"},
		{"name":"myParcelable", "value":"http://foo", "dataType":"Parcelable", "paType":"Uri"},
		{"name":"myParcelableArray", "value":["http://foo","http://bar"], "dataType":"ParcelableArray", "paType":"Uri"},
		{"name":"myParcelableArrayList", "value":["http://foo","http://bar"], "dataType":"ParcelableArrayList", "paType":"Uri"},
		{"name":"mySparseParcelableArray", "value":{"10":"http://foo", "-25":"http://bar"}, "dataType":"SparseParcelableArray", "paType":"Uri"},
	]
```

#### Launcher.canLaunch Success Callback
No data is passed.

#### Launcher.canLaunch Error Callback
Passes a string containing an error message.

#### Launcher.launch Success Callback Data
Passes a JSON object with varying parts.

Activity launched
```javascript
	{
		isLaunched: true
	}
```

Activity finished
```javascript
	{
		isActivityDone: true
	}
```

Activity launched and data returned
```javascript
	{
		isActivityDone: true,
		data: <Uri returned from Activity, if any>,
		extras <JSON object containing data returned from Activity, if any>
	}
```

#### Launcher.launch Error Callback Data
Passes an error message as a string.

## 4. Changelog
0.4.1: Android: Add the ability to call internal activity with intent embeded in aar file. IOS code is removed and custome code added to open arcgis map.

0.4.0: Android: Added ability to launch with intent. Thanks to [@mmey3k] for the code.

0.2.0: Android: Added ability to launch activity with extras and receive data back from launched app when it is finished.

0.1.2: Added ability to check if any apps are installed that can handle a certain datatype on Android.

0.1.1: Added ability to launch a package with a data uri and datatype on Android.

0.1.0: initial version supporting Android and iOS

## 5. Credits
Thank to [@nchutchind](https://github.com/nchutchind) the author of the original github repo.
Special thanks to [@michael1t](https://github.com/michael1t) for sponsoring the development of the Extras portion of this plugin.

## 6. License

[The MIT License (MIT)](http://www.opensource.org/licenses/mit-license.html)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
