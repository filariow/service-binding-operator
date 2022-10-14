## Run

set everything up with

```console
UID=$UID GID=$GID USER=$USER docker compose up --build
```

## Troubleshooting

If you notice problems with kind startup, a problem may be in host's inotify limits

```console
sudo sysctl fs.inotify.max_user_watches=655360
sudo sysctl fs.inotify.max_user_instances=1280
```
