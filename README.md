# Nginx-PageSpeed-OpenSSLBeta
This is a container for deploying nginx with the OpenSSL Beta for RFC-compliant ChaCha support. It also adds the PageSpeed module.

I use this in production to deploy the SSL terminator for the [CryptoParty Newcastle](https://cryptopartynewcastle.org/) site, amongst others. It runs with a configuration that [can be found here](https://github.com/ORGNorthEast/CryptoParty-Newcastle/tree/master/cryptopartynewcastle.org/nginx%20SSL%20Terminator).

Below, you can find my notes from the CryptoParty deployment. You may need to tweak these so they work appropriately for you:

## Deploying Directly from Docker Hub
```
sudo docker run --cap-drop=all --name nginx -p 80:8080 -p 443:4434 -v /home/ssl/keys:/usr/share/nginx/keys:ro -v /home/ssl/nginx.conf:/etc/nginx/nginx.conf:ro -d ajhaydock/nginx
```
In the above example, I am mounting my SSL keys as a read only volume (they are in `/home/ssl/keys` on the host). Similarly, my `nginx.conf` is at `/home/ssl/nginx.conf` on the host.

## Persistence with systemd Services
See [this repo](https://github.com/ORGNorthEast/CryptoParty-Newcastle/raw/master/cryptopartynewcastle.org/nginx%20SSL%20Terminator/sslterminator.service) for a systemd service you can install to ensure that your container comes back up following a reboot.

Use the following commands to copy the service into the appropriate place, then reload the service cache and then enable it:
```
sudo cp -f -v sslterminator.service /etc/systemd/system/sslterminator.service
sudo systemctl daemon-reload
sudo systemctl enable sslterminator.service && sudo systemctl start sslterminator.service
```

## Common Issues
### Permission Denied
If you get an error like the following:
```
nginx: [emerg] open() "/etc/nginx/nginx.conf" failed (13: Permission denied)
```
Then your Docker version is probably way too old. Check the Docker website for instructions on installing the latest version directly from their repositories.

### Other Permission Errors
Make sure that any files you are mounting into the container using Docker Volumes flag are owned by the user with the same UID as the `nginx` user inside the container (currently `1000` based on how I've configured the `Dockerfile`):
```
sudo chown -R 1000:1000 /home/ssl/keys && sudo chown 1000:1000 /home/ssl/nginx.conf
```

### Can't Forward / Listen on Certain Ports
I've configured this container so that it runs the whole webserver (including the nginx master process) as an unprivileged user. This means you need to ensure that your `nginx.conf` is listening on ports above 1000 as only the `root` user can listen on 1000 and below.

In my example above, I listen in the container on `8080` for HTTP, and on `4434` for HTTPS.

### SELinux & Permissions
If you are running an SELinux-enabled host (recommended!), you might run into some issues with Docker containers not being able to write to certain directories (particularly directories inside user homedirs).

Change the SELinux context of your files/directories to allow the container to write as follows:
```
sudo chcon -Rt svirt_sandbox_file_t /home/ssl/keys/nginx.conf
sudo chcon -Rt svirt_sandbox_file_t /home/ssl/keys
```
