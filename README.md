# whisperpush_unregister.rb

A script that will unregister your phone number from CyanogenMod's WhisperPush implementation of TextSecure, allowing you to register with the WhisperSystems TextSecure server instead.

## REQUIREMENTS

You'll need Ruby 1.9 or greater. Ruby 2 strongly recommended, I tested on 2.1.1p76.

As far as I know, all the requirements are in the standard library, so as long as your Ruby includes OpenSSL support then you'll be fine.

## USAGE

Once you've got Ruby and it's in your ```$PATH```, just run the script with ```--help``` to get usage information.  If you're feeling adventurous you can ```chmod +x``` it and let the shebang figure it out, but this will only work on UNIX-like systems.

### The quick version

Assuming that your phone number is ```+16501231234```

```
ruby whisperpush_unregister.rb --mode getconfirm --phone-number +16501231234
   Confirmation code sent to +16501231234. Run with -m unregister when you have it.
```

You'll then be sent a code by SMS, let's say it's ```123-456```

```
ruby whisperpush_unregister.rb --mode unregister --phone-number +16501231234 --code 123456
   Unregistering gcm with 20 rounds....................done.
   Unregistering apn with 20 rounds....................done.
```

You should then be unregistered from WhisperPush. Give it a few minutes and try to register with WhisperSystems' TextSecure. You shouldn't get the 'registered with another server' error now. If it doesn't work, give it another few minutes and try to register again.

### I don't know how to type '--help'

```
Usage: ./whisperpush_unregister.rb [options]

EXAMPLES:
./whisperpush_unregister.rb --mode getconfirm --phone-number +16501231234
./whisperpush_unregister.rb --mode unregister --phone-number +16501231234 --code 123456


    -m, --mode MODE                  Execution mode (getconfirm or unregister)
    -p, --phone-number PHONE_NUMBER  Phone number with leading + and country code
                                     Examples: +16505551234 +442071231234
    -c, --code VALIDATION_CODE       Validation code received by SMS after --mode getconfirm
                                     without any dashes (example: 123456)
    -t, --type PUSH_PROVIDER         Deregister Android ('gcm') or Apple ('apn') endpoints,
                                     or both (default 'both', don't change unless you know
                                     what you're doing and why you want to change this)
```



## Troubleshooting

The script should fail usefully with instructions of what you've done wrong. If it doesn't, open an issue on here, or fork it and send me a pull request with the fix :)

## Contributing changes

Blah blah blah fork blah blah blah pull request blah blah blah open source.

## License

Licensed under [WTFPL][wtfpl-about]. I accept no liability for anything going wrong and promise no fixes, though I'll help if I can.

[wtfpl-about]: http://www.wtfpl.net/about/
