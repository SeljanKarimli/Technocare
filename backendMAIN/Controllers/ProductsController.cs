using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using backend.Models;
using backend.Services;

namespace backend.Controllers
{
    [ApiController]
    [Route("api/internal/legacy/products")]
    [Authorize(Roles = "Admin")]
    [ApiExplorerSettings(IgnoreApi = true)]
    public class ProductsController : ControllerBase
    {
        private readonly ProductService _productService;

        public ProductsController(ProductService productService)
        {
            _productService = productService;
        }

        [HttpGet]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<List<Product>>> Get(
            [FromQuery] string? categoryId = null,
            [FromQuery] string? search = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 100)
        {
            var products = await _productService.GetFilteredAsync(
                categoryId: categoryId,
                search: search,
                page: page,
                pageSize: pageSize);

            return Ok(products);
        }

        [HttpGet("{id:length(24)}")]
        [Authorize(Roles = "Admin")]
        public async Task<ActionResult<Product>> GetById(string id)
        {
            var product = await _productService.GetByIdAsync(id);
            if (product == null) return NotFound();
            return Ok(product);
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Create([FromBody] ProductCreateRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var created = await _productService.CreateAsync(request);
            if (created == null)
            {
                return BadRequest(new
                {
                    message = "Invalid product data."
                });
            }

            return CreatedAtAction(nameof(GetById), new { id = created.Id }, created);
        }

        [HttpPut("{id:length(24)}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Update(string id, [FromBody] ProductUpdateRequest request)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var exists = await _productService.GetByIdAsync(id);
            if (exists == null) return NotFound();

            var ok = await _productService.UpdateAsync(id, request);
            if (!ok)
            {
                return BadRequest(new
                {
                    message = "Update failed."
                });
            }
            return NoContent();
        }

        [HttpDelete("{id:length(24)}")]
        [Authorize(Roles = "Admin")]
        public async Task<IActionResult> Delete(string id)
        {
            var existing = await _productService.GetByIdAsync(id);
            if (existing == null) return NotFound();

            var success = await _productService.DeleteAsync(id);
            if (!success)
                return StatusCode(500, new { message = "Failed to delete product." });

            return NoContent();
        }
    }
}
