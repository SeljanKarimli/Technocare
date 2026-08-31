// Auto base URL: local = current origin, prod = runasp
function getApiBase() {
    return window.location.origin;
}
const API_BASE = getApiBase();

function authHeaders() {
    const token = localStorage.getItem("adminToken");
    return token ? { Authorization: `Bearer ${token}` } : {};
}

// ========= Privacy Gate (Admin only) =========
(function guardAdmin() {
    const raw = localStorage.getItem("adminUser");
    if (!raw) {
        window.location.href = "login.html";
        return;
    }
    try {
        const u = JSON.parse(raw);
        if (u?.role !== "Admin") {
            window.location.href = "login.html";
            return;
        }
    } catch {
        window.location.href = "login.html";
    }
})();

function logout() {
    localStorage.removeItem("adminToken");
    localStorage.removeItem("adminUser");
    window.location.href = "login.html";
}

const messageBox = document.getElementById("app-message-box");
function showMessage(text, type = "danger") {
    if (!messageBox) return;
    messageBox.textContent = text;
    messageBox.className = `alert alert-${type} text-center`;
    messageBox.style.display = "block";
    setTimeout(() => { messageBox.style.display = "none"; }, 3000);
}

function handleApiError(error) {
    if (error.response?.status === 401) {
        showMessage("Unauthorized. Please log in again.", "danger");
        setTimeout(() => (window.location.href = "login.html"), 1500);
        return;
    }
    const msg = error.response?.data?.message || error.message || "Request failed, please try again.";
    showMessage(msg, "danger");
}

// ==========================
// SPA NAV
// ==========================
const sidebar = document.getElementById("sidebar-nav");
const sectionTitle = document.getElementById("section-title");
const sectionAddBtn = document.getElementById("section-add-btn");
const sectionAddBtnText = document.getElementById("section-add-btn-text");

let currentSection = "products";

const SECTION_CONFIG = {
    products: { title: "Product Management", add: true, addText: "Add Product" },
    categories: { title: "Category Management", add: true, addText: "Add Category" },
    orders: { title: "Orders", add: false },
    projects: { title: "Projects", add: true, addText: "Add Project" },
    education: { title: "Education Apps", add: false },
    services: { title: "Service Apps", add: false },
    users: { title: "Users", add: false },
    notifications: { title: "Notifications", add: true, addText: "Create" },
};

function switchSection(sectionKey) {
    currentSection = sectionKey;

    sidebar.querySelectorAll(".nav-link").forEach((link) => {
        link.classList.toggle("active", link.getAttribute("data-section") === sectionKey);
    });

    document.querySelectorAll(".admin-section").forEach((sec) => {
        sec.classList.toggle("active", sec.id === `section-${sectionKey}`);
    });

    const cfg = SECTION_CONFIG[sectionKey] || {};
    sectionTitle.textContent = cfg.title || "";

    if (cfg.add) {
        sectionAddBtn.classList.remove("d-none");
        sectionAddBtnText.textContent = cfg.addText || "Add";
    } else {
        sectionAddBtn.classList.add("d-none");
    }

    loadSection(sectionKey);
}

function loadSection(sectionKey) {
    switch (sectionKey) {
        case "products": loadProducts(); break;
        case "categories": loadCategories(); break;
        case "orders": loadOrders(); break;
        case "projects": loadProjects(); break;
        case "education": loadEducationApps(); break;
        case "services": loadServiceApps(); break;
        case "users": loadUsers(); break;
        case "notifications": loadNotifications(); break;
        default: break;
    }
}

// ==========================
// Shared: Categories cache (for product dropdown + table rendering)
// ==========================
let categoriesCache = []; // [{id,name}]
async function refreshCategoriesCache() {
    const res = await axios.get(`${API_BASE}/api/internal/legacy/categories`, { headers: authHeaders() });
    const cats = res.data || [];
    categoriesCache = cats.map(c => ({
        id: c.id ?? c.Id,
        name: c.name ?? c.Name
    }));
    return categoriesCache;
}
function categoryNameById(categoryId) {
    const id = categoryId ?? "";
    const found = categoriesCache.find(c => c.id === id);
    return found ? found.name : "";
}

// ==========================
// PRODUCT CRUD (fixed to use CategoryId)
// ==========================
const productsTableBody = document.getElementById("products-table-body");
const productModalEl = document.getElementById("product-modal");
const productModal = productModalEl ? new bootstrap.Modal(productModalEl) : null;
const productForm = document.getElementById("product-form");
const saveProductBtn = document.getElementById("save-product-btn");

const confirmModalEl = document.getElementById("confirm-modal");
const confirmModal = confirmModalEl ? new bootstrap.Modal(confirmModalEl) : null;
const confirmDeleteBtn = document.getElementById("confirm-delete-btn");
const confirmModalTitle = document.getElementById("confirm-modal-title");
const confirmModalText = document.getElementById("confirm-modal-text");

let currentDeleteType = null; // "product" | "project"
let currentProductId = null;
let currentProjectId = null;

async function loadProducts() {
    if (!productsTableBody) return;
    productsTableBody.innerHTML = '<tr><td colspan="6" class="text-center">Loading...</td></tr>';

    try {
        // Ensure categories loaded for showing category names
        if (!categoriesCache.length) {
            await refreshCategoriesCache();
        }

        // NOTE: controller route is /api/products (lowercase). Using lowercase avoids issues.
        const res = await axios.get(`${API_BASE}/api/internal/legacy/products?page=1&pageSize=200`, { headers: authHeaders() });
        const products = res.data || [];

        if (!products.length) {
            productsTableBody.innerHTML = '<tr><td colspan="6" class="text-center">No products found.</td></tr>';
            return;
        }

        productsTableBody.innerHTML = "";
        products.forEach((p) => {
            const id = p.id ?? p.Id;
            const name = p.name ?? p.Name ?? "";
            const imageUrl = p.imageUrl ?? p.ImageUrl ?? "";
            const price = (p.price ?? p.Price) != null ? (p.price ?? p.Price) : "";
            const stock = (p.stock ?? p.Stock) != null ? (p.stock ?? p.Stock) : "";
            const categoryId = p.categoryId ?? p.CategoryId;
            const catName = categoryNameById(categoryId);

            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td><img src="${imageUrl}" style="width:50px;height:50px;object-fit:cover;border-radius:4px;"></td>
              <td>${name}</td>
              <td>${catName}</td>
              <td>${price}</td>
              <td>${stock}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${id}" data-action="edit-product">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="delete-product">
                  <i class="bi bi-trash"></i>
                </button>
              </td>
            `;
            productsTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        productsTableBody.innerHTML = '<tr><td colspan="6" class="text-center text-danger">Error loading products.</td></tr>';
    }
}

async function fillProductCategorySelect(selectedId = "") {
    const select = document.getElementById("product-categoryId");
    if (!select) return;

    try {
        await refreshCategoriesCache();
        select.innerHTML = `<option value="">Select category...</option>`;
        categoriesCache.forEach(c => {
            const opt = document.createElement("option");
            opt.value = c.id;
            opt.textContent = c.name;
            if (selectedId && selectedId === c.id) opt.selected = true;
            select.appendChild(opt);
        });
    } catch (err) {
        handleApiError(err);
        select.innerHTML = `<option value="">Failed to load categories</option>`;
    }
}

async function openAddProductModal() {
    if (!productForm) return;
    productForm.reset();
    document.getElementById("product-id").value = "";
    document.getElementById("product-modal-title").textContent = "Add Product";
    await fillProductCategorySelect("");
    productModal?.show();
}

async function openEditProductModal(id) {
    try {
        const res = await axios.get(`${API_BASE}/api/internal/legacy/products/${id}`, { headers: authHeaders() });
        const p = res.data || {};

        document.getElementById("product-id").value = p.id ?? p.Id ?? "";
        document.getElementById("product-name").value = p.name ?? p.Name ?? "";
        document.getElementById("product-description").value = p.description ?? p.Description ?? "";
        document.getElementById("product-price").value = p.price ?? p.Price ?? 0;
        document.getElementById("product-stock").value = p.stock ?? p.Stock ?? 0;
        document.getElementById("product-image").value = p.imageUrl ?? p.ImageUrl ?? "";
        document.getElementById("product-tags").value = Array.isArray(p.tags ?? p.Tags)
            ? (p.tags ?? p.Tags).join(", ")
            : "";

        const categoryId = p.categoryId ?? p.CategoryId ?? "";
        await fillProductCategorySelect(categoryId);

        document.getElementById("product-modal-title").textContent = "Edit Product";
        productModal?.show();
    } catch (err) {
        handleApiError(err);
    }
}

async function saveProduct() {
    const id = document.getElementById("product-id").value;
    const categoryId = document.getElementById("product-categoryId").value;

    const payload = {
        name: document.getElementById("product-name").value.trim(),
        description: document.getElementById("product-description").value.trim(),
        price: parseFloat(document.getElementById("product-price").value),
        stock: parseInt(document.getElementById("product-stock").value, 10),
        imageUrl: document.getElementById("product-image").value.trim(),
        categoryId: categoryId,
        tags: document.getElementById("product-tags").value
            .split(",").map(t => t.trim()).filter(Boolean),
    };

    if (!payload.categoryId) {
        showMessage("Please select a category.", "danger");
        return;
    }

    try {
        if (id) {
            await axios.put(`${API_BASE}/api/internal/legacy/products/${id}`, payload, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Product updated.", "success");
        } else {
            await axios.post(`${API_BASE}/api/internal/legacy/products`, payload, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Product created.", "success");
        }
        productModal?.hide();
        loadProducts();
    } catch (err) {
        handleApiError(err);
    }
}

function confirmDeleteProduct(id) {
    currentProductId = id;
    currentDeleteType = "product";
    if (confirmModalTitle) confirmModalTitle.textContent = "Delete product?";
    if (confirmModalText) confirmModalText.textContent = "Are you sure you want to delete this product?";
    confirmModal?.show();
}

async function deleteProduct() {
    if (!currentProductId) return;
    try {
        await axios.delete(`${API_BASE}/api/internal/legacy/products/${currentProductId}`, { headers: authHeaders() });
        showMessage("Product deleted.", "success");
        confirmModal?.hide();
        loadProducts();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// CATEGORY CRUD (fixed endpoint casing)
// ==========================
const categoriesTableBody = document.getElementById("categories-table-body");
const categoryModalEl = document.getElementById("category-modal");
const categoryModal = categoryModalEl ? new bootstrap.Modal(categoryModalEl) : null;
const saveCategoryBtn = document.getElementById("save-category-btn");

async function loadCategories() {
    if (!categoriesTableBody) return;
    categoriesTableBody.innerHTML = '<tr><td colspan="2" class="text-center">Loading...</td></tr>';
    try {
        const res = await axios.get(`${API_BASE}/api/internal/legacy/categories`, { headers: authHeaders() });
        const cats = res.data || [];
        categoriesCache = cats.map(c => ({ id: c.id ?? c.Id, name: c.name ?? c.Name }));

        if (!cats.length) {
            categoriesTableBody.innerHTML = '<tr><td colspan="2" class="text-center">No categories found.</td></tr>';
            return;
        }

        categoriesTableBody.innerHTML = "";
        categoriesCache.forEach((c) => {
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td>${c.name}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${c.id}" data-action="edit-category">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" data-id="${c.id}" data-action="delete-category">
                  <i class="bi bi-trash"></i>
                </button>
              </td>
            `;
            categoriesTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        categoriesTableBody.innerHTML = '<tr><td colspan="2" class="text-center text-danger">Error loading categories.</td></tr>';
    }
}

function openAddCategoryModal() {
    document.getElementById("category-id").value = "";
    document.getElementById("category-name").value = "";
    document.getElementById("category-modal-title").textContent = "Add Category";
    categoryModal?.show();
}

function openEditCategoryModal(id, name) {
    document.getElementById("category-id").value = id;
    document.getElementById("category-name").value = name;
    document.getElementById("category-modal-title").textContent = "Edit Category";
    categoryModal?.show();
}

async function saveCategory() {
    const id = document.getElementById("category-id").value;
    const name = document.getElementById("category-name").value.trim();

    try {
        if (id) {
            await axios.put(`${API_BASE}/api/internal/legacy/categories/${id}`, { id, name }, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Category updated.", "success");
        } else {
            await axios.post(`${API_BASE}/api/internal/legacy/categories`, { name }, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Category created.", "success");
        }
        categoryModal?.hide();
        loadCategories();
        // Refresh cached categories so product modal stays correct
        await refreshCategoriesCache();
    } catch (err) {
        handleApiError(err);
    }
}

async function deleteCategory(id) {
    if (!confirm("Delete this category?")) return;
    try {
        await axios.delete(`${API_BASE}/api/internal/legacy/categories/${id}`, { headers: authHeaders() });
        showMessage("Category deleted.", "success");
        loadCategories();
        await refreshCategoriesCache();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// ORDERS (with customer details and improved display)
// ==========================
const ordersTableBody = document.getElementById("orders-table-body");
let allOrders = []; // Cache all orders

function safeItemsToHtml(order, detailed = false) {
    const items = order.items ?? order.Items ?? [];
    if (!Array.isArray(items) || !items.length) return `<span class="text-muted">No items</span>`;

    if (detailed) {
        return `
            <table class="table table-sm">
                <thead>
                    <tr>
                        <th>Product</th>
                        <th>Quantity</th>
                        <th>Price</th>
                        <th>Total</th>
                    </tr>
                </thead>
                <tbody>
                    ${items.map(i => {
                        const name = i.productName ?? i.ProductName ?? i.name ?? i.Name ?? i.productId ?? i.ProductId ?? "Item";
                        const qty = i.quantity ?? i.Quantity ?? 0;
                        const price = i.price ?? i.Price ?? 0;
                        const total = qty * price;
                        return `
                            <tr>
                                <td>${name}</td>
                                <td>${qty}</td>
                                <td>${price}</td>
                                <td><strong>${total}</strong></td>
                            </tr>
                        `;
                    }).join("")}
                </tbody>
            </table>
        `;
    }

    return items.map(i => {
        const name = i.productName ?? i.ProductName ?? i.name ?? i.Name ?? i.productId ?? i.ProductId ?? "Item";
        const qty = i.quantity ?? i.Quantity ?? 0;
        const price = i.price ?? i.Price;
        const priceTxt = (price != null) ? ` — ${price}` : "";
        return `<div>• ${name} x${qty}${priceTxt}</div>`;
    }).join("");
}

async function loadOrders() {
    if (!ordersTableBody) return;
    ordersTableBody.innerHTML = '<tr><td colspan="8" class="text-center">Loading...</td></tr>';

    try {
        const res = await axios.get(`${API_BASE}/api/internal/legacy/orders`, { headers: authHeaders() });
        allOrders = res.data || [];

        // Get all users for customer details
        const usersRes = await axios.get(`${API_BASE}/api/auth/users`, { headers: authHeaders() });
        const allUsers = usersRes.data || [];

        // Create user lookup map
        const userMap = new Map();
        allUsers.forEach(user => {
            userMap.set(user.id || user.Id, user);
        });

        if (!allOrders.length) {
            ordersTableBody.innerHTML = '<tr><td colspan="8" class="text-center">No orders found.</td></tr>';
            return;
        }

        ordersTableBody.innerHTML = "";
        allOrders.forEach((o) => {
            const id = o.id ?? o.Id ?? "";
            const userId = o.userId ?? o.UserId ?? "";
            const user = userMap.get(userId) || {};
            const customerName = user.name || user.Name || "Unknown";
            const customerEmail = user.email || user.Email || "N/A";
            const status = o.status ?? o.Status ?? "";
            const total = (o.totalAmount ?? o.TotalAmount ?? o.total ?? o.Total) ?? "0";
            const orderDate = o.orderDate ?? o.OrderDate ?? new Date().toISOString();
            const itemsHtml = safeItemsToHtml(o);

            // Format date
            const formattedDate = new Date(orderDate).toLocaleDateString();

            // Status badge styling
            const statusClass = `status-${status.toLowerCase()}`;

            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${id.substring(0, 8)}...</td>
              <td><strong>${customerName}</strong></td>
              <td class="text-muted small">${customerEmail}</td>
              <td><span class="badge ${statusClass}">${status}</span></td>
              <td><strong>${total}</strong></td>
              <td class="small">${formattedDate}</td>
              <td>${itemsHtml}</td>
              <td>
                <button class="btn btn-sm btn-outline-info me-1" data-id="${id}" data-action="view-order">
                  <i class="bi bi-eye"></i>
                </button>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${id}" data-action="order-status">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="order-delete">
                  <i class="bi bi-trash"></i>
                </button>
              </td>
            `;
            ordersTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        ordersTableBody.innerHTML = '<tr><td colspan="8" class="text-center text-danger">Error loading orders.</td></tr>';
    }
}

async function viewOrderDetails(orderId) {
    try {
        const order = allOrders.find(o => (o.id || o.Id) === orderId);
        if (!order) {
            showMessage("Order not found", "danger");
            return;
        }

        // Get user details
        const userId = order.userId || order.UserId;
        let userDetails = null;
        if (userId) {
            try {
                const userRes = await axios.get(`${API_BASE}/api/auth/users`, { headers: authHeaders() });
                const users = userRes.data || [];
                userDetails = users.find(u => (u.id || u.Id) === userId);
            } catch (e) {
                console.error("Error fetching user details:", e);
            }
        }

        const customerName = userDetails?.name || userDetails?.Name || "Unknown";
        const customerEmail = userDetails?.email || userDetails?.Email || "N/A";
        const customerPhone = userDetails?.phone || userDetails?.Phone || "N/A";

        const orderDetails = `
            <div class="card mb-3">
                <div class="card-body">
                    <h5 class="card-title">Order Information</h5>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>Order ID:</strong> <span class="mono">${order.id || order.Id || ""}</span></p>
                            <p><strong>Status:</strong> <span class="badge status-${(order.status || order.Status || "").toLowerCase()}">${order.status || order.Status || ""}</span></p>
                            <p><strong>Total Amount:</strong> <strong>${order.totalAmount || order.TotalAmount || order.total || order.Total || "0"}</strong></p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Order Date:</strong> ${new Date(order.orderDate || order.OrderDate || new Date()).toLocaleString()}</p>
                            <p><strong>Cart ID:</strong> <span class="mono">${order.cartId || order.CartId || "N/A"}</span></p>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card mb-3">
                <div class="card-body">
                    <h5 class="card-title">Customer Information</h5>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>Name:</strong> ${customerName}</p>
                            <p><strong>Email:</strong> ${customerEmail}</p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Phone:</strong> ${customerPhone}</p>
                            <p><strong>User ID:</strong> <span class="mono">${userId || "N/A"}</span></p>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-body">
                    <h5 class="card-title">Order Items</h5>
                    ${safeItemsToHtml(order, true)}
                </div>
            </div>
        `;

        document.getElementById("order-details-content").innerHTML = orderDetails;
        document.getElementById("order-modal-title").textContent = "Order Details";

        const orderModal = new bootstrap.Modal(document.getElementById("order-modal"));
        orderModal.show();

    } catch (err) {
        handleApiError(err);
    }
}

async function changeOrderStatus(id) {
    const status = prompt("Enter new status (e.g. Pending, Approved, Shipped):");
    if (!status) return;
    try {
        await axios.put(
            `${API_BASE}/api/internal/legacy/orders/${id}/status`,
            { status },
            { headers: { ...authHeaders(), "Content-Type": "application/json" } }
        );
        showMessage("Order status updated.", "success");
        loadOrders();
    } catch (err) {
        handleApiError(err);
    }
}

async function deleteOrder(id) {
    if (!confirm("Delete this order?")) return;
    try {
        await axios.delete(`${API_BASE}/api/internal/legacy/orders/${id}`, { headers: authHeaders() });
        showMessage("Order deleted.", "success");
        loadOrders();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// EDUCATION APPLICATIONS
// ==========================
const educationTableBody = document.getElementById("education-table-body");

async function loadEducationApps() {
    if (!educationTableBody) return;
    educationTableBody.innerHTML = '<tr><td colspan="9" class="text-center">Loading...</td></tr>';
    try {
        const res = await axios.get(`${API_BASE}/api/educationapplications`, { headers: authHeaders() });
        const apps = res.data || [];
        if (!apps.length) {
            educationTableBody.innerHTML = '<tr><td colspan="9" class="text-center">No education applications found.</td></tr>';
            return;
        }
        educationTableBody.innerHTML = "";
        apps.forEach((a) => {
            const id = a.id ?? a.Id;
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${id}</td>
              <td>${a.applicantName || a.ApplicantName || ""}</td>
              <td>${a.applicantEmail || a.ApplicantEmail || ""}</td>
              <td>${a.applicantPhone || a.ApplicantPhone || ""}</td>
              <td>${a.appliedFor || a.AppliedFor || ""}</td>
              <td>${a.message || a.Message || ""}</td>
              <td>${a.applicationDate || a.ApplicationDate || ""}</td>
              <td>${a.status || a.Status || ""}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${id}" data-action="edu-status">Set Status</button>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="edu-delete">Delete</button>
              </td>
            `;
            educationTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        educationTableBody.innerHTML = '<tr><td colspan="9" class="text-center text-danger">Error loading education applications.</td></tr>';
    }
}

async function changeEducationStatus(id) {
    const status = prompt("Enter new status:");
    if (!status) return;
    try {
        await axios.put(
            `${API_BASE}/api/educationapplications/${id}/status`,
            { status },
            { headers: { ...authHeaders(), "Content-Type": "application/json" } }
        );
        showMessage("Education application status updated.", "success");
        loadEducationApps();
    } catch (err) {
        handleApiError(err);
    }
}

async function deleteEducationApp(id) {
    if (!confirm("Delete this education application?")) return;
    try {
        await axios.delete(`${API_BASE}/api/educationapplications/${id}`, { headers: authHeaders() });
        showMessage("Education application deleted.", "success");
        loadEducationApps();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// SERVICE APPLICATIONS
// ==========================
const servicesTableBody = document.getElementById("services-table-body");

async function loadServiceApps() {
    if (!servicesTableBody) return;
    servicesTableBody.innerHTML = '<tr><td colspan="9" class="text-center">Loading...</td></tr>';
    try {
        const res = await axios.get(`${API_BASE}/api/serviceapplications`, { headers: authHeaders() });
        const apps = res.data || [];
        if (!apps.length) {
            servicesTableBody.innerHTML = '<tr><td colspan="9" class="text-center">No service applications found.</td></tr>';
            return;
        }
        servicesTableBody.innerHTML = "";
        apps.forEach((a) => {
            const id = a.id ?? a.Id;
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${id}</td>
              <td>${a.applicantName || a.ApplicantName || ""}</td>
              <td>${a.applicantEmail || a.ApplicantEmail || ""}</td>
              <td>${a.applicantPhone || a.ApplicantPhone || ""}</td>
              <td>${a.appliedFor || a.AppliedFor || ""}</td>
              <td>${a.message || a.Message || ""}</td>
              <td>${a.applicationDate || a.ApplicationDate || ""}</td>
              <td>${a.status || a.Status || ""}</td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${id}" data-action="service-status">Set Status</button>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="service-delete">Delete</button>
              </td>
            `;
            servicesTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        servicesTableBody.innerHTML = '<tr><td colspan="9" class="text-center text-danger">Error loading service applications.</td></tr>';
    }
}

async function changeServiceStatus(id) {
    const status = prompt("Enter new status:");
    if (!status) return;
    try {
        await axios.put(
            `${API_BASE}/api/serviceapplications/${id}/status`,
            { status },
            { headers: { ...authHeaders(), "Content-Type": "application/json" } }
        );
        showMessage("Service application status updated.", "success");
        loadServiceApps();
    } catch (err) {
        handleApiError(err);
    }
}

async function deleteServiceApp(id) {
    if (!confirm("Delete this service application?")) return;
    try {
        await axios.delete(`${API_BASE}/api/serviceapplications/${id}`, { headers: authHeaders() });
        showMessage("Service application deleted.", "success");
        loadServiceApps();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// USERS (with full user details)
// ==========================
const usersTableBody = document.getElementById("users-table-body");
let allUsers = []; // Cache all users

async function loadUsers() {
    if (!usersTableBody) return;
    usersTableBody.innerHTML = '<tr><td colspan="10" class="text-center">Loading...</td></tr>';

    try {
        // Get all users from auth endpoint
        const usersRes = await axios.get(`${API_BASE}/api/auth/users`, { headers: authHeaders() });
        allUsers = usersRes.data || [];

        // Get orders and applications for stats
        const [ordersRes, eduRes, srvRes] = await Promise.all([
            axios.get(`${API_BASE}/api/internal/legacy/orders`, { headers: authHeaders() }),
            axios.get(`${API_BASE}/api/educationapplications`, { headers: authHeaders() }),
            axios.get(`${API_BASE}/api/serviceapplications`, { headers: authHeaders() }),
        ]);

        const orders = ordersRes.data || [];
        const edu = eduRes.data || [];
        const srv = srvRes.data || [];

        // Calculate stats for each user
        const userStats = new Map();

        allUsers.forEach(user => {
            const userId = user.id || user.Id || "";
            userStats.set(userId, {
                orders: orders.filter(o => (o.userId || o.UserId) === userId).length,
                education: edu.filter(e => (e.userId || e.UserId) === userId).length,
                service: srv.filter(s => (s.userId || s.UserId) === userId).length
            });
        });

        if (!allUsers.length) {
            usersTableBody.innerHTML = '<tr><td colspan="10" class="text-center">No users found.</td></tr>';
            return;
        }

        usersTableBody.innerHTML = "";
        allUsers.forEach((user) => {
            const userId = user.id || user.Id || "";
            const stats = userStats.get(userId) || { orders: 0, education: 0, service: 0 };
            const name = user.name || user.Name || "Unknown";
            const email = user.email || user.Email || "";
            const phone = user.phone || user.Phone || "N/A";
            const role = user.role || user.Role || "User";
            const verified = user.emailVerified !== undefined ? user.emailVerified : (user.EmailVerified || false);

            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${userId.substring(0, 8)}...</td>
              <td><strong>${name}</strong></td>
              <td>${email}</td>
              <td>${phone}</td>
              <td><span class="badge ${role === 'Admin' ? 'bg-primary' : 'bg-secondary'}">${role}</span></td>
              <td class="text-center">
                ${verified ?
                    '<i class="bi bi-check-circle-fill text-success"></i>' :
                    '<i class="bi bi-x-circle-fill text-danger"></i>'}
              </td>
              <td class="text-center"><span class="badge bg-info">${stats.orders}</span></td>
              <td class="text-center"><span class="badge bg-warning">${stats.education}</span></td>
              <td class="text-center"><span class="badge bg-success">${stats.service}</span></td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${userId}" data-action="view-user">
                  <i class="bi bi-eye"></i>
                </button>
                ${role !== 'Admin' ? `
                <button class="btn btn-sm btn-outline-danger" data-id="${userId}" data-action="delete-user">
                  <i class="bi bi-trash"></i>
                </button>` : ''}
              </td>
            `;
            usersTableBody.appendChild(tr);
        });

    } catch (err) {
        handleApiError(err);
        usersTableBody.innerHTML = '<tr><td colspan="10" class="text-center text-danger">Error loading users.</td></tr>';
    }
}

async function viewUserDetails(userId) {
    try {
        const user = allUsers.find(u => (u.id || u.Id) === userId);
        if (!user) {
            showMessage("User not found", "danger");
            return;
        }

        const userDetails = `
            <div class="card">
                <div class="card-body">
                    <h5 class="card-title">${user.name || user.Name || "Unknown"}</h5>
                    <h6 class="card-subtitle mb-2 text-muted">${user.email || user.Email || ""}</h6>
                    <hr>
                    <div class="row">
                        <div class="col-md-6">
                            <p><strong>User ID:</strong> <span class="mono">${user.id || user.Id || ""}</span></p>
                            <p><strong>Phone:</strong> ${user.phone || user.Phone || "N/A"}</p>
                            <p><strong>Role:</strong> <span class="badge ${user.role === 'Admin' ? 'bg-primary' : 'bg-secondary'}">${user.role || user.Role || "User"}</span></p>
                        </div>
                        <div class="col-md-6">
                            <p><strong>Email Verified:</strong> ${user.emailVerified !== undefined ? (user.emailVerified ? '✅ Yes' : '❌ No') : (user.EmailVerified ? '✅ Yes' : '❌ No')}</p>
                            <p><strong>Cart ID:</strong> <span class="mono">${user.cartId || user.CartId || "N/A"}</span></p>
                        </div>
                    </div>
                </div>
            </div>
        `;

        document.getElementById("user-details-content").innerHTML = userDetails;
        document.getElementById("user-modal-title").textContent = "User Details";

        const userModal = new bootstrap.Modal(document.getElementById("user-modal"));
        userModal.show();

    } catch (err) {
        handleApiError(err);
    }
}

async function deleteUser(userId) {
    if (!confirm("Are you sure you want to delete this user? This action cannot be undone.")) return;

    try {
        await axios.delete(`${API_BASE}/api/auth/users/${userId}`, { headers: authHeaders() });
        showMessage("User deleted successfully", "success");
        loadUsers();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// PROJECTS (kept, only minor confirm delete fix)
// ==========================
const projectsTableBody = document.getElementById("projects-table-body");
const projectModalEl = document.getElementById("project-modal");
const projectModal = projectModalEl ? new bootstrap.Modal(projectModalEl) : null;
const projectForm = document.getElementById("project-form");
const saveProjectBtn = document.getElementById("save-project-btn");

function parseImagesCsv(val) {
    return (val || "").split(",").map(x => x.trim()).filter(Boolean);
}

async function loadProjects() {
    if (!projectsTableBody) return;

    projectsTableBody.innerHTML = '<tr><td colspan="7" class="text-center">Loading...</td></tr>';

    try {
        const res = await axios.get(`${API_BASE}/api/internal/legacy/projects`, { headers: authHeaders() });
        const projects = res.data || [];

        if (!projects.length) {
            projectsTableBody.innerHTML = '<tr><td colspan="7" class="text-center">No projects found.</td></tr>';
            return;
        }

        projectsTableBody.innerHTML = "";
        projects.forEach((p) => {
            const id = p.id ?? p.Id ?? "";
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${id}</td>
              <td>${p.name || p.Name || ""}</td>
              <td style="max-width:260px;">${p.description || p.Description || ""}</td>
              <td style="max-width:220px;">
                ${p.imageUrl ? `<a href="${p.imageUrl}" target="_blank">Open</a>` : ""}
              </td>
              <td style="max-width:260px;">
                ${Array.isArray(p.images) ? p.images.length : 0}
              </td>
              <td style="max-width:320px;">
                <div class="small">${(p.content || "").length > 120 ? p.content.slice(0, 120) + "…" : (p.content || "")}</div>
              </td>
              <td>
                <button class="btn btn-sm btn-outline-primary me-1" data-id="${id}" data-action="edit-project">
                  <i class="bi bi-pencil"></i>
                </button>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="delete-project">
                  <i class="bi bi-trash"></i>
                </button>
              </td>
            `;
            projectsTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        projectsTableBody.innerHTML = '<tr><td colspan="7" class="text-center text-danger">Error loading projects.</td></tr>';
    }
}

function openAddProjectModal() {
    if (!projectForm) return;
    projectForm.reset();
    document.getElementById("project-id").value = "";
    document.getElementById("project-modal-title").textContent = "Add Project";
    projectModal?.show();
}

async function openEditProjectModal(id) {
    try {
        const res = await axios.get(`${API_BASE}/api/internal/legacy/projects/${id}`, { headers: authHeaders() });
        const p = res.data || {};

        document.getElementById("project-id").value = p.id ?? p.Id ?? "";
        document.getElementById("project-name").value = p.name ?? p.Name ?? "";
        document.getElementById("project-description").value = p.description ?? p.Description ?? "";
        document.getElementById("project-imageUrl").value = p.imageUrl ?? p.ImageUrl ?? "";
        document.getElementById("project-images").value = Array.isArray(p.images ?? p.Images) ? (p.images ?? p.Images).join(", ") : "";
        document.getElementById("project-content").value = p.content ?? p.Content ?? "";

        document.getElementById("project-modal-title").textContent = "Edit Project";
        projectModal?.show();
    } catch (err) {
        handleApiError(err);
    }
}

async function saveProject() {
    const id = document.getElementById("project-id").value;

    const payload = {
        name: document.getElementById("project-name").value.trim(),
        description: document.getElementById("project-description").value.trim(),
        imageUrl: document.getElementById("project-imageUrl").value.trim(),
        images: parseImagesCsv(document.getElementById("project-images").value),
        content: document.getElementById("project-content").value.trim(),
    };

    try {
        if (id) {
            await axios.put(`${API_BASE}/api/internal/legacy/projects/${id}`, payload, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Project updated.", "success");
        } else {
            await axios.post(`${API_BASE}/api/internal/legacy/projects`, payload, {
                headers: { ...authHeaders(), "Content-Type": "application/json" },
            });
            showMessage("Project created.", "success");
        }

        projectModal?.hide();
        loadProjects();
    } catch (err) {
        handleApiError(err);
    }
}

function confirmDeleteProject(id) {
    currentProjectId = id;
    currentDeleteType = "project";
    if (confirmModalTitle) confirmModalTitle.textContent = "Delete project?";
    if (confirmModalText) confirmModalText.textContent = "Are you sure you want to delete this project?";
    confirmModal?.show();
}

async function deleteProject() {
    if (!currentProjectId) return;
    try {
        await axios.delete(`${API_BASE}/api/internal/legacy/projects/${currentProjectId}`, { headers: authHeaders() });
        showMessage("Project deleted.", "success");
        confirmModal?.hide();
        loadProjects();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// NOTIFICATIONS (list + create + delete)
// ==========================
const notificationsTableBody = document.getElementById("notifications-table-body");
const notificationModalEl = document.getElementById("notification-modal");
const notificationModal = notificationModalEl ? new bootstrap.Modal(notificationModalEl) : null;
const saveNotificationBtn = document.getElementById("save-notification-btn");

async function loadNotifications() {
    if (!notificationsTableBody) return;
    notificationsTableBody.innerHTML = '<tr><td colspan="5" class="text-center">Loading...</td></tr>';
    try {
        const res = await axios.get(`${API_BASE}/api/notifications/all`, { headers: authHeaders() });
        const list = res.data || [];
        if (!list.length) {
            notificationsTableBody.innerHTML = '<tr><td colspan="5" class="text-center">No notifications found.</td></tr>';
            return;
        }
        notificationsTableBody.innerHTML = "";
        list.forEach((n) => {
            const id = n.id ?? n.Id;
            const tr = document.createElement("tr");
            tr.innerHTML = `
              <td class="mono">${id}</td>
              <td>${n.title || n.Title || ""}</td>
              <td>${n.message || n.Message || ""}</td>
              <td>${n.createdAt || n.CreatedAt || ""}</td>
              <td>
                <button class="btn btn-sm btn-outline-danger" data-id="${id}" data-action="notification-delete">
                  <i class="bi bi-trash"></i>
                </button>
              </td>
            `;
            notificationsTableBody.appendChild(tr);
        });
    } catch (err) {
        handleApiError(err);
        notificationsTableBody.innerHTML = '<tr><td colspan="5" class="text-center text-danger">Error loading notifications.</td></tr>';
    }
}

async function deleteNotification(id) {
    if (!confirm("Delete this notification?")) return;
    try {
        await axios.delete(`${API_BASE}/api/notifications/${id}`, { headers: authHeaders() });
        showMessage("Notification deleted.", "success");
        loadNotifications();
    } catch (err) {
        handleApiError(err);
    }
}

async function createNotification() {
    const title = document.getElementById("notification-title").value.trim();
    const message = document.getElementById("notification-message").value.trim();
    const userId = document.getElementById("notification-userId").value.trim();

    if (!title || !message) {
        showMessage("Title and Message are required.", "danger");
        return;
    }

    // Best-effort payload (CreateNotificationRequest)
    // If your service expects different property names, we can adjust instantly.
    const payload = {
        title,
        message,
        userId: userId || null
    };

    try {
        await axios.post(`${API_BASE}/api/notifications`, payload, {
            headers: { ...authHeaders(), "Content-Type": "application/json" },
        });
        showMessage("Notification sent.", "success");
        notificationModal?.hide();
        loadNotifications();
    } catch (err) {
        handleApiError(err);
    }
}

// ==========================
// EVENT WIRING
// ==========================
document.addEventListener("DOMContentLoaded", () => {
    // Logout
    const logoutLink = document.getElementById("logout-link");
    if (logoutLink) logoutLink.addEventListener("click", (e) => { e.preventDefault(); logout(); });

    // sidebar nav
    sidebar.querySelectorAll(".nav-link[data-section]").forEach((link) => {
        link.addEventListener("click", (e) => {
            e.preventDefault();
            const sec = link.getAttribute("data-section");
            if (sec) switchSection(sec);
        });
    });

    // global add button
    sectionAddBtn.addEventListener("click", () => {
        if (currentSection === "products") openAddProductModal();
        if (currentSection === "categories") openAddCategoryModal();
        if (currentSection === "projects") openAddProjectModal();
        if (currentSection === "notifications") {
            // open notification modal
            document.getElementById("notification-title").value = "";
            document.getElementById("notification-message").value = "";
            document.getElementById("notification-userId").value = "";
            notificationModal?.show();
        }
    });

    // save product
    if (saveProductBtn) saveProductBtn.addEventListener("click", (e) => { e.preventDefault(); saveProduct(); });

    // confirm delete (product/project)
    if (confirmDeleteBtn) confirmDeleteBtn.addEventListener("click", async (e) => {
        e.preventDefault();
        if (currentDeleteType === "product") await deleteProduct();
        if (currentDeleteType === "project") await deleteProject();
    });

    // products table actions
    if (productsTableBody) {
        productsTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "edit-product") openEditProductModal(id);
            if (action === "delete-product") confirmDeleteProduct(id);
        });
    }

    // categories
    if (saveCategoryBtn) saveCategoryBtn.addEventListener("click", (e) => { e.preventDefault(); saveCategory(); });
    if (categoriesTableBody) {
        categoriesTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            const row = btn.closest("tr");
            const name = row?.querySelector("td")?.textContent ?? "";
            if (action === "edit-category") openEditCategoryModal(id, name);
            if (action === "delete-category") deleteCategory(id);
        });
    }

    // projects actions
    if (projectsTableBody) {
        projectsTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "edit-project") openEditProjectModal(id);
            if (action === "delete-project") confirmDeleteProject(id);
        });
    }
    if (saveProjectBtn) saveProjectBtn.addEventListener("click", (e) => { e.preventDefault(); saveProject(); });

    // orders
    if (ordersTableBody) {
        ordersTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "view-order") viewOrderDetails(id);
            if (action === "order-status") changeOrderStatus(id);
            if (action === "order-delete") deleteOrder(id);
        });
    }

    // users
    if (usersTableBody) {
        usersTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "view-user") viewUserDetails(id);
            if (action === "delete-user") deleteUser(id);
        });
    }

    // user search
    const userSearch = document.getElementById("user-search");
    if (userSearch) {
        userSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = usersTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // product search
    const productSearch = document.getElementById("product-search");
    if (productSearch) {
        productSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = productsTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // category search
    const categorySearch = document.getElementById("category-search");
    if (categorySearch) {
        categorySearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = categoriesTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // project search
    const projectSearch = document.getElementById("project-search");
    if (projectSearch) {
        projectSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = projectsTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // education search
    const educationSearch = document.getElementById("education-search");
    if (educationSearch) {
        educationSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = educationTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // service search
    const serviceSearch = document.getElementById("service-search");
    if (serviceSearch) {
        serviceSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = servicesTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // notification search
    const notificationSearch = document.getElementById("notification-search");
    if (notificationSearch) {
        notificationSearch.addEventListener("input", (e) => {
            const searchTerm = e.target.value.toLowerCase();
            const rows = notificationsTableBody?.querySelectorAll("tr") || [];
            rows.forEach(row => {
                const text = row.textContent.toLowerCase();
                row.style.display = text.includes(searchTerm) ? "" : "none";
            });
        });
    }

    // order search and filter
    const orderSearch = document.getElementById("order-search");
    const orderStatusFilter = document.getElementById("order-status-filter");

    function filterOrders() {
        const searchTerm = (orderSearch?.value || "").toLowerCase();
        const statusFilter = orderStatusFilter?.value || "";
        const rows = ordersTableBody?.querySelectorAll("tr") || [];

        rows.forEach(row => {
            const text = row.textContent.toLowerCase();
            const statusBadge = row.querySelector(".badge");
            const rowStatus = statusBadge?.textContent.toLowerCase() || "";

            const matchesSearch = text.includes(searchTerm);
            const matchesStatus = !statusFilter || rowStatus === statusFilter.toLowerCase();

            row.style.display = (matchesSearch && matchesStatus) ? "" : "none";
        });
    }

    if (orderSearch) orderSearch.addEventListener("input", filterOrders);
    if (orderStatusFilter) orderStatusFilter.addEventListener("change", filterOrders);

    // education apps
    if (educationTableBody) {
        educationTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "edu-status") changeEducationStatus(id);
            if (action === "edu-delete") deleteEducationApp(id);
        });
    }

    // service apps
    if (servicesTableBody) {
        servicesTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "service-status") changeServiceStatus(id);
            if (action === "service-delete") deleteServiceApp(id);
        });
    }

    // notifications
    if (notificationsTableBody) {
        notificationsTableBody.addEventListener("click", (e) => {
            const btn = e.target.closest("button");
            if (!btn) return;
            const action = btn.getAttribute("data-action");
            const id = btn.getAttribute("data-id");
            if (action === "notification-delete") deleteNotification(id);
        });
    }
    if (saveNotificationBtn) saveNotificationBtn.addEventListener("click", (e) => { e.preventDefault(); createNotification(); });

    // initial section
    switchSection("products");
});
