// Models/MongoDbSettings.cs
namespace backend.Models
{
    public class MongoDbSettings
    {
        public string ConnectionString { get; set; } = null!;
        public string DatabaseName { get; set; } = null!;
        public string UsersCollectionName { get; set; } = null!;
        public string ProductsCollectionName { get; set; } = null!;
        public string CategoriesCollectionName { get; set; } = null!;
        public string CartsCollectionName { get; set; } = null!;
        public string OrdersCollectionName { get; set; } = null!;
        public string ServiceApplicationsCollectionName { get; set; } = null!;
        public string EducationApplicationsCollectionName { get; set; } = null!;
        public string AddressesCollectionName { get; set; } = null!; // Changed from AdressesCollectionName
        public string NotificationsCollectionName { get; set; } = null!;
        public string ProjectsCollectionName { get; set; } = null!;
    }
}