locals {
  nets = {
    admins = ["40.68.4.20/30","147.102.11.201/32"]
    srv_mgmt2  = ["10.220.1.33"]
    vpn_network = ["192.168.232.0/24"]
  }

  net_acls_groups = {
    admin_ips_global      = distinct(concat(local.nets["admins"],local.nets["vpn_network"]))
    developers_global     = distinct(concat(local.nets["vpn_network"],local.nets["srv_mgmt2"]))
    developers_internal   = distinct(concat(local.nets["vpn_network"],local.nets["srv_mgmt2"]))
  }

  net_acls_scope = {
    our_users = distinct(concat(local.net_acls_groups["developers_global"],local.net_acls_groups["admin_ips_global"]))
  }

  net_outgoing_sgs = {
    "all" =  { 
      "all" = { port = 0},
    }
    # "allvpc" =  { 
    #   "all" = { port = 0, range = [local.vpc_cidr] },
    # }
    # "http" = {
    #   "http" = { port = 80 ,proto = "tcp"},
    #   "https" = { port = 443, proto = "tcp" },
    # }
  }


  net_incoming_sgs = {
    # "icmp" = {
    #   "all_icmp" = { from_port = -1, to_port = -1, proto = "icmp" }
    # }
    "all" =  { 
      "all" = { port = 0},
    }
    # "admin" =  { 
    #   "admin_all" = { port = 0, range = local.net_acls_groups["admin_ips_global"]},
    # }
    # "devs" =  { 
    #   "devs_smb" = { port = 445, proto = "tcp", range = local.net_acls_groups["developers_internal"]},
    #   "devs_rdp" = { port = 3389, proto = "tcp", range = local.net_acls_groups["developers_internal"]},
    #   "devs_ssh" = { port = 22, proto = "tcp", range = local.net_acls_groups["developers_internal"]},
    # }    
    # "allvpc" =  { 
    #   "vpc_all" = { port = 0, range = [local.vpc_cidr] },
    # }    
    "lb" = {
      "http" = { port = 80 ,proto = "tcp"},
      "https" = { port = 443, proto = "tcp" },
    }    
    # "httpApps" = {
    #   "http" = { port = 80, proto = "tcp" },
    #   "https" = { port = 443, proto = "tcp" },
    #   "http-alt" = { from_port = 8000, to_port = 8100 ,proto = "tcp" },
    # }
    # "sql" = {
    #   "devs_sql" = { port = 1433, proto = "tcp", range = concat([local.vpc_cidr],local.net_acls_groups["developers_internal"])  },
    # }    
  }

}