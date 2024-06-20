# Vpc 
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr_block = var.vpc_cidr_block
  public_subnet_cidr_blocks = var.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = var.private_subnet_cidr_blocks
  availability_zones = var.availability_zones

}
#iam role for ec2
module "aws_iam_role" {
  depends_on = [ module.vpc ]
  source = "./modules/iam"
  role_name = var.role_name
  iam_policy_name = var.iam_policy_name
  instance_profile_name = var.instance_profile_name
}
module "ec2_instance"{
  depends_on = [ module.vpc, module.aws_iam_role ]
  source = "./modules/ec2"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  instance_profile_name =  module.aws_iam_role.instance_profile_name
  ami_id = var.ami_id
  instance_type_strapi = var.instance_type_strapi
}