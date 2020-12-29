# Contact Manager

A sample application that shows an agile approach to building a Mac Application.

## Resources

* [Code Coverage](http://qualitycoding.org/xcode-code-coverage/#comment-1807)
* Loading OCMock (frameworks)
  * [How to load OCMock in you test bundle](http://www.mulle-kybernetik.com/forum/viewtopic.php?f=4&t=271&sid=baddd9135cb7e12facc56cdc66e3ba9f)
  * [Using @rpath Why and How](http://www.dribin.org/dave/blog/archives/2009/11/15/rpath/)
  * [Linking and Install Names](http://www.mikeash.com/pyblog/friday-qa-2009-11-06-linking-and-install-names.html)
* [Generating Code Coverage Files with LLVM](http://meandmark.com/blog/2012/08/xcode-4-generating-code-coverage-files-with-llvm/)
* [Retrieving Coverage Information – LLVM, CoverStory and Teamcity](http://jorudolph.wordpress.com/2011/08/10/retrieving-coverage-information-llvm-coverstory-and-teamcity/)
* [How to setup quality metrics on your Jenkins job?](http://blog.octo.com/en/jenkins-quality-dashboard-ios-development/)
* [Code coverage output seems to be broken in Xcode 4.4 (you will need a developer account)](https://devforums.apple.com/message/717814)

### To Build

You can locally override the Xcode settings for code signing
by creating a `DeveloperSettings.xcconfig` file locally in the project directory.
This allows for a pristine project with code signing set up with the appropriate
developer ID and certificates, and for a developer to be able to have local settings
without needing to check in anything into source control.

Create a plain text file in it: `DeveloperSettings.xcconfig` and
give it the contents:

```text
DEVELOPMENT_TEAM = <Your Team ID>
CODE_SIGN_IDENTITY = Mac Developer
CODE_SIGN_STYLE = Automatic
ORGANIZATION_IDENTIFIER = <Your Domain Name Reversed>
```

Set `DEVELOPMENT_TEAM` to your Apple supplied development team. You can use Keychain
Access to find you Development Team ID:

* Open Keychain Access on your development machine.
* On the left-hand side, make sure "My Certificates" is selected.
* Find the certificate that reads `Apple Development: <Your Name>`
* Right click on the certificate and select "Get Info".

Your **Development Team ID** is the value next to **Organizational Unit**.

Set `ORGANIZATION_IDENTIFIER` to a reversed domain name that you control or have made up.

You should be able to open the `ContactManager.xccodeproj` in Xcode and build without code signing errors and without modifying
the ghNotifier Xcode project.

```shell
./scripts/bootstrap.sh
```

### To Update

```shell
./scripts/update.sh
```