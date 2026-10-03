## pixie

Pixie allows me to netboot any machine (x86) and install and configure an OS without needing to have a USB handy. It uses PXE boot to load the OS, cloud config for Ubuntu auto install, and Ansible for configuration.  

As I’ve started to lean into my infrastructure and distributed systems interests, I took inspiration from my day job. Running the day-to-day ops of an IT Help Desk, we image and configure hundreds to thousands of machines a year (all Windows and MacOS). Those of you in the IT world know Macs are a bit more nuanced, but we have a Microsoft Deployment Toolkit instance running using PXE to help automate that process.  

In exploring distributed systems, I’ve recently added 2 mini pcs to my homelab. Eventually, these will be worker nodes in a Kubernetes cluster that I’m developing, but for now they are just compute nodes, each with 4 cores and 32GB of RAM. When I initially got them, I manually set each of them up, and realized how tedious the process was. If I want to truly practice the idea that all compute should be truly ephemeral, I would need to automate this configuration process to allow for the rapid addition of other nodes (or the simulation of new nodes by wiping a current node).  

That leads me to Pixie – my local solution to automating the setup and configuration of new compute nodes in my cluster. I have already been working on and successfully deploying automated VM provisioning through my homelab project (link). That uses the cloud-init technology developed by canonical and the Proxmox API. That process is great for spinning up VM’s but not for the addition of new physical nodes.  

After some adjustments to the configuration files, Pixie can be deployed with a simple `docker compose up –d`. This will then pull the the iso from thier source (in my case, Ubutnu 24.04 and 26.04), parse them, and confiure them to be used with PXE.  

This project was a great combination of work related solutions and project related issues! 

