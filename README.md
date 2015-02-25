# dokku deployment step

Deploy your code to a dokku(-alt) host. (All further mentioning of dokku also applies to dokku-alt)

# Using wercker SSH key pair

You should generate a private/public key pair on wercker and manually add the public key to the dokku host.

- Generate a new key in wercker in the `Key management` section (`application` - `settings`).
- Copy the public key and add it on the intended dokku host.
  - for dokku this could be something like ```cat $wercker.pub | ssh dokku-host "sudo sshcommand acl-add dokku $USER"```
  - for dokku-alt this could be something like ```cat $wercker.pub | ssh dokku@dokku-host deploy:allow $app-name```
- In wercker edit the dokku deploy target to which you would like to deploy, and add an environment variable:
    - Give the environment variable a name (remember this name, you will need it in the last step).
    - Select `SSH Key pair` as the type and select the key pair which you created earlier.
- In the `dokku-deploy` step in your `wercker.yml` add the `key-name` property with the value you used earlier:

``` yaml
deploy:
    steps:
        - dokku-deploy:
            key-name: MY_DEPLOY_KEY
            dokku-host: dokkuhost.com
```

In the above example the `MY_DEPLOY_KEY` should match the environment variable name you used in wercker. Note: you should not prefix it with a dollar sign or post fix it with `_PRIVATE` or `_PUBLIC`.

# Options

* `key-name` (optional) Specify the name of the key that should be used for this deployment.
* `retry` (optional) When a deploy to dokku fails, a new deploy is automatically performed after 5 seconds. If you want to disable this behavior, set `retry` to `false`.
* `keep-repository` (optional) This will allow a user to keep the original history of the repository, speeding up deployment. **Important:** changes made during the build will not be deployed. Also keep in mind that deploying an already up to date repo will not result in an application restart. Use the `run` parameter to forcibly reload to achieve this. This feature is considered beta, expect issues. If you find one, please contact us.

# Example

``` yaml
deploy:
    steps:
        - dokku-deploy:
            key-name: MY_DEPLOY_KEY
            dokku-host: dokkuhost.com
```
# License

The MIT License (MIT)

# Changelog

## 0.0.1

* Initial release based of the excellent work already done by wercker themselves as the heroku-deploy-step.
