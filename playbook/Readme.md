## Ansible Playbook for provider deployment.

### Steps:
- Edit the hostname into the playbook
- Add required hosts into the inventory.ini file (Ansible will create a user spheron with password spheron, update the system and install necessaary init scripts)
- To Run:
    ```shell
    ansible-playbook -i inventory.ini playbook.yml
    ```
