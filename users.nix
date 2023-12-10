let key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSwkiglk4jruYa7uWBmRecpgX0RV0WaYaIW7++pfUgNCKFWol8fGaNjH98J7jTNKYZouKAYls3nXbIUQlX6Ku0c8/Ubco6asARWbZlrZUgwJw34FLOmBIzNhE+SBrScplTyvwgFPFH+cbqJR1GnjZT/51d7rhx4bPFSb0n3J1Rh77WkfyR+Q9WPEXEcM8FbkHSqy9y8U633+pKazusJmNSjHs50loMHsBfGxy0qridOb48t+sFamcGXQzMHgPrJ8dBnjtEDMh3eVnoarp7lyo+bpbKa84WEjDGTvGTRIZKykKGgT+TIZ94pKSVoUc2n6NHURNtgG+44HqBU/EdFOb8Nn+F3gUj9aDakZz/u3BsOT0+5pC7t9ZJnzKiT/hVK27eJm8NxN+itsiRyWSoW8NXmYG0RSxtZ5R6equZD8YNeyLARauJbcz8DwjB71kwU/94UigbUGnyMnxM3CRSyvALwS9wMwnLtQ3dXLTp55sXkhoFE6nBQnFCBBm72b/Ct9l7yBf7+uQajY5JQVHrLoITlq5MIj+xUVdLM5dpnFl6pH6SRi84PI/eWd9TiHiH3//XobY5e0doO6yOevTN6MlnQCEPqIYmDIlPd7k+RAog1rXb17EfjSTjjKCWWNS557VFwxkafMVCL84FramhIecgO0ckPEGB9kwyEpBGWh/dKw== jan@Jan-Laptop";
in {
  users.root.openssh.authorizedKeys.keys = [ key ];

  users.jan = {
    name = "Jan";
    isNormalUser = true;
    group = "users";
    extraGroups = [ "wheel" ];
    createHome = true;

    openssh.authorizedKeys.keys = [ key ];
  };
}
