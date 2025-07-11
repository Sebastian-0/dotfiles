import ipykernel
import re


# Expose a function to get the kernel id
def get_kernel_id():
    """Get the current kernel ID"""
    return re.match(r".*-(.*?)\.json", ipykernel.connect.get_connection_file()).group(1)
