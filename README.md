# KWEI

`kwei` is a simple compartmentalization tool for ComputerCraft. It allows you to create `containers` that have independent file systems and that can only access APIs and peripherals as you chose to configure them. This allows you to run individual programs in sandboxed environments. They may also share certain directories, allowing you to run all your programs in different containers while taking full advantage of them.

## Installation

### Pastebin

The fastest way to install `kwei` is to use the Pastebin installer. It will download all the required files as well as setup your system to run `kwei`. Note that it requires internet access to work.

Run the installer with the following command: 
```
pastebin run 8rKBtPhy
```

### From the GitHub installer

The installer is also available on GitHub. It should be the same as the Pastebin one, but it's easier to modify if you want to make changes. Note that it requires internet access to work.

Download and run the installer with the following commands:
```
wget https://raw.githubusercontent.com/KodiCraft/kwei/main/install.lua install.lua
install
```

### Manual installation

Installing kwei manually will require you to manually download all the required files as well as performing the basic setup yourself. This is not recommended for most users.

You will first need the following basic file system structure:
```
/
├── usr
│   ├── bin (is where the kwei binary will be installed)
│   └── lib (is where additional libraries will be installed)
├── etc
└── var
    ├── log (is where the logs will be stored)
    └── kwei
        └── containers (is where the containers will be stored)
```

Then, you will need to download the file [kwei.lua](https://raw.githubusercontent.com/KodiCraft/kwei/main/pkg/usr/bin/kwei.lua) and place it in `/usr/bin/kwei.lua`. You will also need to download every file in the [lib](https://github.com/KodiCraft/kwei/tree/main/pkg/usr/lib) directory with the name starting in `k-` and place them in `/usr/lib/`. Note that `bios` files are not required at this step.

Next, you will have to download the bios file for your *CC: Tweaked* version. Begin by checking which version you are running with: 
```
about
```

You will get an output similar to this:
```
CraftOS 1.8 on ComputerCraft 1.103.1
```

You first want to check if there is a bios file for your version in the repository. For instance, if you are on ComputerCraft `1.101.0`, you are looking for a file at `pkg/usr/lib/101-bios.lua`. If that file exists, you can download it with the following command:
```
wget https://raw.githubusercontent.com/KodiCraft/kwei/main/pkg/usr/lib/101-bios.lua /usr/lib/bios.lua
```

Otherwise, you will have to download the bios file from the official *CC: Tweaked* repository. You can do so by running the following command:
```
wget https://raw.githubusercontent.com/SquidDev-CC/CC-Tweaked/master/src/main/resources/data/computercraft/lua/bios.lua /usr/lib/bios.lua
```

Keep in mind that this means that you risk running into bugs and compatibility issues. Please file a [GitHub issue](https://github.com/KodiCraft/kwei/issues) if the version you are using is not supported. 

Finally, you will have to setup the following settings:
```
set kwei.path.home /var/kwei
set kwei.path.dl /tmp
set kwei.log.level warn
set kwei.log.file /var/log/kwei.log
```


## Usage

```
help - show this help message
passwd - set the admin password
create <name> [image] - create a new container from an image
shell <container> - open a shell in a container
run <container> [pastebin] <script/id> - run a script in a container
addperm <container> <permission> - add a permission to a container
rmperm <container> <permission> - remove a permission from a container
listperms [container] - list permissions of a container or all possible permissions
mount <container> <host_path> <container_path> - mount a path from the host filesystem into a container (container path is absolute)
umount <container> <host_path> - unmount a path from a container
lsmounts <container> - list all mounts of a container
addperi <container> <peripheral> [innername] - add a peripheral to a container
rmperi <container> <peripheral> - remove a peripheral from a container
listperis <container> - list all peripherals of a container
list - list all containers
delete <container> - delete a container
```

## Examples

### Creating a container

To create a container, you can use the `create` command. It takes a name as its first argument and an optional image as its second argument. Image support is currently not implemented, so you can only use the default image. 

```
kwei create my_container
```

### Opening the shell of a container

Once you have created a container, you can start using it by opening a shell in it. You can do so with the `shell` command. It takes the name of the container as its first argument.

```
kwei shell my_container
```

### Running a script in a container

If you don't want to bother with navigating the shell, you can also run a script in a container. You can do so with the `run` command. It takes the name of the container as its first argument, followed by the path of the script to run. If the script is a pastebin script, you can use the `pastebin` argument to specify it.

```
kwei run my_container pastebin 8rKBtPhy
```

### Mounting a directory from the host filesystem

In order to allow a container to access the host filesystem, you will have to mount a directory from the host filesystem into the container. You can do so with the `mount` command. It takes the name of the container as its first argument, followed by the path of the directory to mount from the host filesystem and the path of the directory to mount in the container. The container path is absolute.

```
kwei mount my_container /home/script /script
```

This will mount the directory `/home/script` from the host filesystem into the container at `/script`. You can then access the files in that directory from the container. Modifications made to the files in the container will be reflected in the host filesystem, and vice versa. 

If you need to unmount a directory, you can use the `umount` command. It takes the name of the container as its first argument, followed by the path of the directory to unmount.

```
kwei umount my_container /home/script
```

**Warning:** Do not unmount the `rom` directory from a container. This will render the container completely unusable.
**Warning:** Do not mount the `kwei.path.home` directory or any directory containing it. This may completely break kwei and/or your system.

### Adding a peripheral to a container

In order to allow a container to access peripherals, you can add a virtual peripheral to it that will bridge to one of the physical peripherals connected to your system. You can do so with the `addperi` command. It takes the name of the container as its first argument, followed by the name of the peripheral to bridge to and an optional name for the virtual peripheral. If no name is specified, the name of the peripheral will be used.

```
kwei addperi my_container left
```

Or, with a custom name:

```
kwei addperi my_container left printer
```

This will add a virtual peripheral named `printer` to the container that will bridge to the peripheral on the left side of the computer. You can then access the peripheral from the container.

If you need to remove a peripheral from a container, you can use the `rmperi` command. It takes the name of the container as its first argument, followed by the name of the peripheral to remove.

```
kwei rmperi my_container left
```

### Grating permissions to a container

By default, containers are not allowed to access the `http` or `debug` APIs as these are considered unsafe. If you wish to allow a container to access these APIs, you can grant it the `http` or `debug` permission. You can do so with the `addperm` command. It takes the name of the container as its first argument, followed by the name of the permission to grant.

```
kwei addperm my_container http
```

If you need to remove a permission from a container, you can use the `rmperm` command. It takes the name of the container as its first argument, followed by the name of the permission to remove.

```
kwei rmperm my_container http
```

### Listing permissions of a container

If you want to know which permissions a container has, you can use the `listperms` command. It takes the name of the container as its first argument. If no container is specified, it will list all possible permissions.

```
kwei listperms my_container
```

## License

This project is licensed under the ComputerCraft Public License. See the [LICENSE](https://github.com/KodiCraft/kwei/blob/main/LICENSE) file for more details.

This project additionally includes modified versions of files from the [CC: Tweaked](https://github.com/SquidDev-CC/CC-Tweaked) project. These files are licensed under the ComputerCraft Public License. See the [LICENSE](https://github.com/SquidDev-CC/CC-Tweaked/blob/master/LICENSE) file for more details.