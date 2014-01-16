FacebookManager
===============

A very lightweight subset of the official [Facebook iOS SDK](https://github.com/facebook/facebook-ios-sdk) useful just for tracking mobile app installations and being able to attribute them to [Facebook Mobile App Ads For Installs](https://developers.facebook.com/docs/ads-for-apps/mobile-app-ads/). Specifically it implements a single initial ping and tracking event to your Facebook App using the Facebook Graph API. This flows the (iOS6+) advertiser identifier and the ``fb_app_attribution`` data which the Facebook iOS app places on the system pasteboard if an install occured from the Facebook iOS app. The tracking data about use and installs will show up with a 2-day lag as daily-/weekly-/monthly-active user information and daily installs in your applications Insights, and it will show up as installs in near real-time during active Mobile App Ads campaigns. (Update: the new Insights dashboard no longer has 2-day lag, find it at https://www.facebook.com/insights/<Your-Facebook-App-ID>)

The code consolidates and compacts the logic found in [FBUtility.m](https://github.com/facebook/facebook-ios-sdk/blob/master/src/FBUtility.m#L358-L403) which is called from [FBSettings.m](https://github.com/facebook/facebook-ios-sdk/blob/master/src/FBSettings.m#L371-L387) and uses a standard ``NSURLConnection`` instead of the heavier (but more useful in general cases) ``FBRequest`` object of the full SDK.

If you are only interested in running Facebook Mobile App Install Ad Campaigns, this is all the Facebook SDK logic you need.


Installation & Use
==

To integrate ``FacebookManager`` into your project:
 1. first create a Facebook Application / Page for your application using the documentation found under [Register Your App](https://developers.facebook.com/docs/ads-for-apps/mobile-app-ads#register-your-app). This will give you a Facebook App ID.
 2. Add the App ID and optionally the name into your iOS bundle's ``Info.plist`` file using the instructions under [Configure the ``plist``](https://developers.facebook.com/docs/ios/getting-started#configure).
 3. Add ``FacebookManager.m`` and ``FacebookManager.h`` to your project.
 4. In your application's startup logic, make this call ``[[FacebookManager sharedInstance] publishInstall]``. Since this code uses ``NSURLConnection``'s asynchronous callbacks it will not stall your application launch, but feel free to defer this logic until after you bring up your UI.
 5. It's a good idea to step through the ``publishInstall`` logic in the debugger, on a device or in the simulator, to make sure that you are seeing a single publish of ``event=MOBILE_APP_INSTALL`` which succeeds, as there are enough strange ID's and keys and other nonsense you have to keep in sync and just right between the Facebook App page and your bundle-id, etc.

Once you've shipped your iOS application follow the rest of the instructions at [Mobile App Ads for Installs](https://developers.facebook.com/docs/ads-for-apps/mobile-app-ads) to create some test ads.


